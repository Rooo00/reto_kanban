#!/bin/bash
set -e

LAMBDA="kanban_manager"
API="KanbanAPI"
REGION=$(aws configure get region)
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ROLE=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

# Empaquetar lambda
zip -r function.zip lambda_function.py >/dev/null

# Crear o actualizar Lambda
if aws lambda get-function --function-name $LAMBDA >/dev/null 2>&1; then
    aws lambda update-function-code \
        --function-name $LAMBDA \
        --zip-file fileb://function.zip
else
    aws lambda create-function \
        --function-name $LAMBDA \
        --runtime python3.12 \
        --role $ROLE \
        --handler lambda_function.lambda_handler \
        --zip-file fileb://function.zip \
        --timeout 30 \
        --memory-size 128
fi

# Crear API HTTP
API_ID=$(aws apigatewayv2 create-api \
    --name $API \
    --protocol-type HTTP \
    --query ApiId --output text)

LAMBDA_ARN="arn:aws:lambda:$REGION:$ACCOUNT:function:$LAMBDA"

# Integración
INTEGRATION=$(aws apigatewayv2 create-integration \
    --api-id $API_ID \
    --integration-type AWS_PROXY \
    --integration-uri $LAMBDA_ARN \
    --payload-format-version 2.0 \
    --query IntegrationId --output text)

# Rutas
for R in "POST /card" "GET /card" "PUT /card/{id}" "DELETE /card/{id}"; do
    aws apigatewayv2 create-route \
        --api-id $API_ID \
        --route-key "$R" \
        --target integrations/$INTEGRATION
done

# Permiso API -> Lambda
aws lambda add-permission \
    --function-name $LAMBDA \
    --statement-id apigateway \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT:$API_ID/*/*"

# Stage
aws apigatewayv2 create-stage \
    --api-id $API_ID \
    --stage-name prod \
    --auto-deploy

echo "API lista:"
echo "https://$API_ID.execute-api.$REGION.amazonaws.com/prod/card"