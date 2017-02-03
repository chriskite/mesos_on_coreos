#!/bin/bash
set -e
export MARATHON_TASK_LAUNCH_TIMEOUT=300000
exec marathon
