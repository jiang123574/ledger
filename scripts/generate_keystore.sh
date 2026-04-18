#!/bin/bash
# 生成 Release 签名 Keystore
# 用法: ./scripts/generate_keystore.sh
#
# ⚠️ 重要：Keystore 文件是 App 唯一身份标识，丢失后无法更新 App
# 请妥善保管，建议备份到密码管理器或加密存储

set -e

KEYSTORE_DIR="android/app/keystore"
KEYSTORE_FILE="$KEYSTORE_DIR/ledger-release.jks"
KEY_ALIAS="ledger"

echo "🔐 Ledger Android Release Keystore 生成工具"
echo ""

# 创建目录
mkdir -p "$KEYSTORE_DIR"

if [ -f "$KEYSTORE_FILE" ]; then
    echo "⚠️  Keystore 已存在: $KEYSTORE_FILE"
    read -p "是否覆盖？(y/N): " confirm
    if [ "$confirm" != "y" ]; then
        echo "已取消"
        exit 0
    fi
fi

echo ""
echo "📝 请填写以下信息："
echo ""

read -p "Keystore 密码: " KEYSTORE_PASSWORD
read -p "Key 密码 (通常与 Keystore 密码相同): " KEY_PASSWORD
read -p "姓名 (CN): " NAME
read -p "组织单位 (OU): " OU
read -p "组织 (O): " O
read -p "城市 (L): " CITY
read -p "省份 (ST): " STATE
read -p "国家代码 (CN): " COUNTRY

DNAME="CN=$NAME, OU=$OU, O=$O, L=$CITY, ST=$STATE, C=$COUNTRY"

# 生成 Keystore
keytool -genkeypair \
    -v \
    -keystore "$KEYSTORE_FILE" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10950 \
    -storepass "$KEYSTORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "$DNAME"

echo ""
echo "✅ Keystore 已生成: $KEYSTORE_FILE"
echo ""

# 生成 keystore.properties（不提交到 Git）
PROPS_FILE="android/keystore.properties"
cat > "$PROPS_FILE" << EOF
storePassword=$KEYSTORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=keystore/ledger-release.jks
EOF

echo "✅ 签名配置已写入: $PROPS_FILE"
echo ""
echo "⚠️  安全提醒："
echo "  1. keystore.properties 已加入 .gitignore，不会被提交"
echo "  2. 请将 $KEYSTORE_FILE 备份到安全位置"
echo "  3. 丢失 Keystore = 无法更新 Play Store 上的 App"
