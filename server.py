#!/usr/bin/env python

import SimpleHTTPServer
import SocketServer

server = SocketServer.TCPServer(('127.0.0.1', 8080), SimpleHTTPServer.SimpleHTTPRequestHandler)
server.serve_forever()

