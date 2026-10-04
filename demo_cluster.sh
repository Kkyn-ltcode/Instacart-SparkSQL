#!/usr/bin/env bash
# Cluster demo: Spark Standalone (1 Master + 2 Workers via Multipass)
# Dataset: Instacart (37.3 million rows)

set -e

MASTER_VM="spark-master"
WORKER1_VM="spark-worker-1"
WORKER2_VM="spark-worker-2"

MASTER_IP="192.168.252.5"
WORKER1_IP="192.168.252.3"
WORKER2_IP="192.168.252.4"

MASTER_URL="spark://${MASTER_IP}:7077"
MASTER_WEBUI="http://${MASTER_IP}:8080"
WORKER1_WEBUI="http://${WORKER1_IP}:8081"
WORKER2_WEBUI="http://${WORKER2_IP}:8081"

# 1. Kiem tra trang thai may ao Multipass
echo "Kiem tra trang thai may ao Multipass..."
VM_LIST=$(multipass list)

for vm in "$MASTER_VM" "$WORKER1_VM" "$WORKER2_VM"; do
    if echo "$VM_LIST" | grep -q "$vm.*Running"; then
        echo "  - $vm: running"
    else
        echo "  - $vm: stopped, starting..."
        multipass start "$vm"
    fi
done

# 2. Kiem tra dich vu Spark Master
echo "Kiem tra Spark Master tren $MASTER_VM ($MASTER_IP)..."
if multipass exec "$MASTER_VM" -- bash -c "jps | grep -q Master"; then
    echo "  - Master: active"
else
    echo "  - Master: stopped, starting..."
    multipass exec "$MASTER_VM" -- bash -c "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 && /home/ubuntu/spark/sbin/start-master.sh -h $MASTER_IP -p 7077 --webui-port 8080"
fi

# 3. Kiem tra dich vu Spark Workers
echo "Kiem tra Spark Workers..."
for w_vm in "$WORKER1_VM" "$WORKER2_VM"; do
    if multipass exec "$w_vm" -- bash -c "jps | grep -q Worker"; then
        echo "  - Worker tren $w_vm: active"
    else
        echo "  - Worker tren $w_vm: stopped, connecting to Master..."
        multipass exec "$w_vm" -- bash -c "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 && /home/ubuntu/spark/sbin/start-worker.sh $MASTER_URL"
    fi
done

echo ""
echo "=== Thong tin ket noi cum Spark ==="
echo "  - Master URL     : $MASTER_URL"
echo "  - Master Web UI  : $MASTER_WEBUI"
echo "  - Worker 1 Web UI: $WORKER1_WEBUI"
echo "  - Worker 2 Web UI: $WORKER2_WEBUI"
echo "  - App Web UI     : http://${MASTER_IP}:4040 (khi co job dang chay)"
echo "==================================="

while true; do
    echo ""
    echo "Chon thao tac:"
    echo "  1) Chay demo phep JOIN 4 bang tren 37.3M dong"
    echo "  2) Chay 10 truy van Spark SQL phan tan"
    echo "  3) Mo Master Web UI tren trinh duyet"
    echo "  4) Kiem tra tai nguyen va tien trinh JVM"
    echo "  5) Mo shell ket noi vao spark-master"
    echo "  6) Khoi dong lai toan bo cum Spark"
    echo "  0) Thoat"
    read -p "Lua chon [0-6]: " choice

    case $choice in
        1)
            echo "Gui tac vu len cum qua spark-submit..."
            multipass exec "$MASTER_VM" -- bash -c "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 && /home/ubuntu/spark/bin/spark-submit /home/ubuntu/run_cluster_3nodes.py"
            ;;
        2)
            echo "Chay 10 truy van phan tan..."
            multipass exec "$MASTER_VM" -- bash -c "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 && /home/ubuntu/spark/bin/spark-submit /home/ubuntu/run_all_10_queries_cluster.py"
            ;;
        3)
            echo "Mo $MASTER_WEBUI..."
            open "$MASTER_WEBUI"
            ;;
        4)
            echo "Trang thai cum tu API:"
            curl -s "http://${MASTER_IP}:8080/json/" | grep -E "url|aliveworkers|cores|memory|status"
            echo ""
            echo "Tien trinh JVM tren cac node:"
            echo "--- $MASTER_VM ---"; multipass exec "$MASTER_VM" -- jps
            echo "--- $WORKER1_VM ---"; multipass exec "$WORKER1_VM" -- jps
            echo "--- $WORKER2_VM ---"; multipass exec "$WORKER2_VM" -- jps
            ;;
        5)
            echo "Ket noi shell $MASTER_VM..."
            multipass shell "$MASTER_VM"
            ;;
        6)
            echo "Khoi dong lai cum Spark..."
            multipass exec "$MASTER_VM" -- bash -c "/home/ubuntu/spark/sbin/stop-master.sh" || true
            multipass exec "$WORKER1_VM" -- bash -c "/home/ubuntu/spark/sbin/stop-worker.sh" || true
            multipass exec "$WORKER2_VM" -- bash -c "/home/ubuntu/spark/sbin/stop-worker.sh" || true
            sleep 2
            multipass exec "$MASTER_VM" -- bash -c "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 && /home/ubuntu/spark/sbin/start-master.sh -h $MASTER_IP -p 7077 --webui-port 8080"
            sleep 2
            multipass exec "$WORKER1_VM" -- bash -c "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 && /home/ubuntu/spark/sbin/start-worker.sh $MASTER_URL"
            multipass exec "$WORKER2_VM" -- bash -c "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 && /home/ubuntu/spark/sbin/start-worker.sh $MASTER_URL"
            echo "Khoi dong lai thanh cong."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Lua chon khong hop le."
            ;;
    esac
done
