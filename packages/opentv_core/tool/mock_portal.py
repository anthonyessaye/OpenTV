import json, http.server, socketserver, urllib.parse

TS = bytes([0x47] + [0x11]*187) * 40   # looks like real MPEG-TS

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)
        action = (q.get('action') or [None])[0]

        if u.path == '/player_api.php':
            if action is None:
                body = {"user_info": {"username":"u","auth":1,"status":"Active",
                        "exp_date":"1786000000","is_trial":"0","active_cons":"1",
                        "max_connections":"2","allowed_output_formats":["ts","m3u8"]},
                        "server_info": {"url":"localhost","port":"8099",
                        "timestamp_now":1755864000}}
            elif action == 'get_live_streams':
                body = [{"stream_id":100+i,"name":f"Channel {i}","num":i,
                         "epg_channel_id":(f"c{i}.tv" if i%2==0 else ""),
                         "category_id":"1","tv_archive":i%3==0}
                        for i in range(5)]
            elif action == 'get_vod_streams':
                body = [{"stream_id":500+i,"name":f"Film {i}",
                         "container_extension":["mkv","mp4",""][i%3],
                         "category_id":"2","rating":"7.1"} for i in range(4)]
            elif action == 'get_series':
                body = [{"series_id":900+i,"name":f"Show {i}","category_id":"3"}
                        for i in range(3)]
            else:
                body = []
            return self._json(body)

        if u.path == '/xmltv.php':
            xml = ('<?xml version="1.0"?><tv>'
                   '<channel id="c0.tv"><display-name>Channel 0</display-name></channel>'
                   '<programme start="20260822180000 +0000" stop="20260822190000 +0000" '
                   'channel="c0.tv"><title>News</title></programme>'
                   '</tv>').encode()
            self.send_response(200)
            self.send_header('Content-Type','application/xml')
            self.send_header('Content-Length',str(len(xml)))
            self.end_headers(); self.wfile.write(xml); return

        parts = [p for p in u.path.split('/') if p]
        if parts and parts[0] in ('live','movie','series'):
            payload = TS if parts[0]=='live' else b'\x00\x00\x00\x20ftypisom' + b'\x00'*2000
            self.send_response(206)
            self.send_header('Content-Type','video/mp2t' if parts[0]=='live' else 'video/mp4')
            self.send_header('Content-Length',str(len(payload)))
            self.end_headers(); self.wfile.write(payload); return

        self.send_response(404); self.end_headers()

    def _json(self, body):
        b = json.dumps(body).encode()
        self.send_response(200)
        self.send_header('Content-Type','application/json')
        self.send_header('Content-Length',str(len(b)))
        self.end_headers(); self.wfile.write(b)

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", 8099), H) as s:
    s.serve_forever()
