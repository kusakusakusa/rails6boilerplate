#!/bin/bash

set -e

rm -f /workspace/tmp/pids/server.pid

exec "$@"