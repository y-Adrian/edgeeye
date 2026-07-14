#!/usr/bin/env python3
"""edgeeye_http_server.py — 静态文件服务，带 HLS MIME + CORS。"""
import http.server
import mimetypes
import os
import sys


class EdgeEyeHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **getattr(http.server.SimpleHTTPRequestHandler, "extensions_map", {}),
        ".m3u8": "application/vnd.apple.mpegurl",
        ".ts": "video/mp2t",
        ".mp4": "video/mp4",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".js": "application/javascript",
        ".json": "application/json",
        ".html": "text/html",
        ".css": "text/css",
    }

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    if len(sys.argv) < 3:
        print("usage: edgeeye_http_server.py <port> <web_root>", file=sys.stderr)
        sys.exit(1)
    port = int(sys.argv[1])
    root = sys.argv[2]
    os.chdir(root)
    # 确保 mimetypes 也认识 m3u8（部分系统默认没有）
    mimetypes.add_type("application/vnd.apple.mpegurl", ".m3u8")
    mimetypes.add_type("video/mp2t", ".ts")
    http.server.HTTPServer(("0.0.0.0", port), EdgeEyeHandler).serve_forever()


if __name__ == "__main__":
    main()
