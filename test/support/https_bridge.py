#!/usr/bin/env python3
"""Isolated CI-only local TLS bridge for the published independent Rails Echo Server.

Accepts only loopback; rewrites ONLY the original HTTP Agent Card JSONRPC URL
to test HTTPS. It does NOT simulate the server's JSON-RPC behavior and must
never be run on an exposed interface or used in production.
"""
import argparse
import http.client
import http.server
import json
import ssl

DEMO_HOST = "127.0.0.1"
DEMO_PORT = 3000
MAX_BYTES = 1048576
TLS_HOST = "echo-agent.test"


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, _format, *_args):
        pass  # No request body, URL query, headers or credentials in CI logs.

    def do_GET(self):
        self.forward()

    def do_POST(self):
        self.forward()

    def forward(self):
        if self.command == "GET":
            if self.path != "/.well-known/agent-card.json":
                self.send_error(404)
                return
        elif self.path != "/a2a":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_error(400)
            return
        if length < 0 or length > MAX_BYTES:
            self.send_error(413)
            return
        data = self.rfile.read(length) if length else b""
        # Do not forward credentials through an unauthenticated local bridge.
        headers = {"Host": f"{DEMO_HOST}:{DEMO_PORT}"}
        for name in ("Content-Type", "A2A-Version"):
            if self.headers.get(name):
                headers[name] = self.headers[name]
        upstream = http.client.HTTPConnection(DEMO_HOST, DEMO_PORT, timeout=8)
        try:
            upstream.request(self.command, self.path, body=data, headers=headers)
            reply = upstream.getresponse()
            payload = reply.read(MAX_BYTES + 1)
            if len(payload) > MAX_BYTES:
                self.send_error(502)
                return
            if self.command == "GET" and reply.status == 200:
                card = json.loads(payload)
                interfaces = card.get("supportedInterfaces", [])
                for interface in interfaces:
                    if (interface.get("protocolBinding") == "JSONRPC"
                            and interface.get("protocolVersion") == "1.0"):
                        interface["url"] = f"https://{TLS_HOST}:{self.server.server_port}/a2a"
                payload = json.dumps(card, separators=(",", ":")).encode()
            self.send_response(reply.status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except (OSError, ValueError, json.JSONDecodeError):
            self.send_error(502)
        finally:
            upstream.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--certificate", required=True)
    parser.add_argument("--key", required=True)
    args = parser.parse_args()
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 3443), Handler)
    tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    tls.load_cert_chain(certfile=args.certificate, keyfile=args.key)
    server.socket = tls.wrap_socket(server.socket, server_side=True)
    try:
        server.serve_forever(poll_interval=0.1)
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
