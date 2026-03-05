#!/bin/bash
set -e

REGION="us-east-1"
TABLE_NAME="KanbanCards"

# Crear tabla DynamoDB
aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions \
        AttributeName=card_id,AttributeType=S \
    --key-schema \
        AttributeName=card_id,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region $REGION

echo "Tabla $TABLE_NAME creada"


aws dynamodb wait table-exists --table-name $TABLE_NAME --region $REGION
echo "Tabla activa y lista para usar."