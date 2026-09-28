"""
Serve HTTP requests with a fixed CPU-time budget per work request.
"""

from __future__ import annotations

import hashlib
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

WORK_SECONDS = int(os.environ.get("WORK_MILLISECONDS", "100")) / 1000


class Handler(BaseHTTPRequestHandler):
    """
    Handle receiver health checks and CPU-bound work requests.
    """

    def do_GET(self) -> None:
        """
        Respond to a health check or consume the configured CPU budget for work.

        Returns:
            None: The response is written to the HTTP connection.
        """
        if self.path not in ("/healthz", "/work"):
            self.send_error(404)
            return
        if self.path == "/work":
            deadline = time.thread_time() + WORK_SECONDS
            while time.thread_time() < deadline:
                hashlib.pbkdf2_hmac("sha256", b"autoscaling-demo", b"work", 1000)
        body = b"ok\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        """
        Suppress per-request access logs during load generation.

        Args:
            format (str): Access-log format supplied by the HTTP server.
            *args (object): Values for the server's log format.

        Returns:
            None: Requests produce no access-log output.
        """


if __name__ == "__main__":
    print("Receiver listening on :8080", flush=True)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
