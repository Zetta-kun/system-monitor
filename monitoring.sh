#!/bin/bash

# ============================================
# SYSTEM MONITORING SCRIPT
# ============================================


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/system_monitor.log"
ALERT_LOG="$SCRIPT_DIR/alerts.log"


if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

# ============================================
# FUNCTIONS
# ============================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1" | tee -a "$ALERT_LOG"
    echo -e "${RED}1${NC}"
}


check_disk() {
    echo -e "${BLUE}--- DISK USAGE ---${NC}"
    
    if command -v df &> /dev/null; then
        df -h | grep -E '^/dev/' | while read line; do
            mount=$(echo "$line" | awk '{print $6}')
            use=$(echo "$line" | awk '{print $5}' | sed 's/%//')
            if [ -n "$use" ] && [ "$use" -gt 80 ] 2>/dev/null; then
                alert "Disk $mount usage is ${use}% (limit 80%)"
            fi
            echo "$line" | awk '{print $1, $5, $6}'
        done
    else
        echo "f command not found"
    fi
    echo ""
}


check_ram() {
    echo -e "${BLUE}--- RAM USAGE ---${NC}"
    
    if command -v free &> /dev/null; then
        free -h | grep -E '^Mem:|^内存:'
    else
        if [ -f /proc/meminfo ]; then
            total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
            available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
            total_mb=$((total / 1024))
            available_mb=$((available / 1024))
            used_mb=$((total_mb - available_mb))
            echo "RAM: ${used_mb}MB / ${total_mb}MB used"
        else
            echo "Cannot get RAM information"
        fi
    fi
    echo ""
}


check_cpu() {
    echo -e "${BLUE}--- CPU LOAD ---${NC}"
    
    if command -v uptime &> /dev/null; then
        uptime | awk '{print "Load average: " $(NF-2) ", " $(NF-1) ", " $NF}'
    fi
    
    if [ -f /proc/loadavg ]; then
        cat /proc/loadavg | awk '{print "1min: "$1", 5min: "$2", 15min: "$3}'
    fi
    echo ""
}


check_uptime() {
    echo -e "${BLUE}--- SYSTEM UPTIME ---${NC}"
    
    if command -v uptime &> /dev/null; then
        uptime -p 2>/dev/null || uptime | awk -F 'up ' '{print $2}' | awk -F ',' '{print $1}'
    fi
    echo ""
}


check_top_processes() {
    echo -e "${BLUE}--- TOP 5 CPU PROCESSES ---${NC}"
    
    if command -v ps &> /dev/null; then
        ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5 | awk '{print $3"% - " $11}'
    else
        echo "ps command not found"
    fi
    echo ""
}


check_port() {
    local port=$1
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            echo "Port $port: listening"
            return 0
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo "Port $port: listening"
            return 0
        fi
    else
        echo "Port $port: cannot check"
    fi
    echo "Port $port: not listening"
    return 1
}


check_service() {
    local service=$1
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "$service: active"
            return 0
        else
            echo "$service: inactive"
            alert "$service service is not running!"
            return 1
        fi
    else
        if pgrep -x "$service" >/dev/null 2>&1; then
            echo "$service: running"
        else
            echo "$service: not running"
            alert "$service service is not running!"
        fi
    fi
}


check_disk_space() {
    echo -e "${BLUE}--- FREE DISK SPACE ---${NC}"
    if command -v df &> /dev/null; then
        df -h / | tail -1 | awk '{print "Root: " $4 " free (" $5 " used)"}'
    fi
    echo ""
}

# ============================================
# HELP MESSAGE
# ============================================
show_help() {
    cat << EOF
Usage: $0 [options]

Options:
  -h, --help      Show this help message
  -p, --port PORT Check specific port
  -s, --service   Check services only (nginx, mysql, docker)
  -a, --all       Run all checks (default)

Examples:
  $0              Run all checks
  $0 -p 80        Check port 80
  $0 -s           Check services only
  $0 -a           Run all checks
EOF
}

# ============================================
# MAIN PROCESS
# ============================================

PORT_CHECK=""
SERVICE_ONLY=0
ALL_CHECK=1

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--port)
            PORT_CHECK="$2"
            ALL_CHECK=0
            shift 2
            ;;
        -s|--service)
            SERVICE_ONLY=1
            ALL_CHECK=0
            shift
            ;;
        -a|--all)
            ALL_CHECK=1
            shift
            ;;
        *)
            echo "Unknown parameter: $1"
            show_help
            exit 1
            ;;
    esac
done

# Header
echo ""
echo "========================================="
echo "       SYSTEM MONITORING"
echo "       $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
echo ""

log "Monitoring started"


if [ -n "$PORT_CHECK" ]; then
    check_port "$PORT_CHECK"
    echo ""
    exit 0
fi


if [ $SERVICE_ONLY -eq 1 ]; then
    check_service "nginx"
    check_service "mysql"
    check_service "docker"
    echo ""
    exit 0
fi


if [ $ALL_CHECK -eq 1 ]; then
    check_uptime
    check_disk
    check_ram
    check_cpu
    check_disk_space
    check_top_processes
    check_service "nginx"
    check_service "mysql"
    check_service "docker"
fi

log "Monitoring completed"

echo "========================================="
echo "Log file: $LOG_FILE"
echo "Alert file: $ALERT_LOG"
echo "========================================="
echo ""
