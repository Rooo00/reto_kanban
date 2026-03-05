#!/bin/bash
set -e

# Configuración básica
LAMBDA_NAME="kanban_manager"
API_NAME="KanbanAPI"
REGION=$(aws configure get region)
# Usamos el comando de tu referencia para obtener el Rol del Lab
LAB_ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

echo "Usando el rol de Learner's Lab: $LAB_ROLE_ARN"

# 1. Empaquetar la Lambda
# Asegúrate de que lambda_function.py esté en la misma carpeta
echo "Empaquetando Lambda..."
zip -r function.zip lambda_function.py

# 2. Crear o Actualizar la Lambda
if aws lambda get-function --function-name "$LAMBDA_NAME" >/dev/null 2>&1; then
    echo "Actualizando código de la Lambda existente..."
    aws lambda update-function-code \
        --function-name "$LAMBDA_NAME" \
        --zip-file "fileb://function.zip"
else
    echo "Creando nueva Lambda..."
    aws lambda create-function \
        --function-name "$LAMBDA_NAME" \
        --runtime "python3.12" \
        --role "$LAB_ROLE_ARN" \
        --handler "lambda_function.lambda_handler" \
        --zip-file "fileb://function.zip" \
        --timeout 30 \
        --memory-size 128
fi

# 3. Configurar API Gateway (HTTP API)
echo "Configurando API Gateway..."
API_ID=$(aws apigatewayv2 create-api \
    --name "$API_NAME" \
    --protocol-type HTTP \
    --query 'ApiId' --output text)

LAMBDA_ARN="arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:$LAMBDA_NAME"

# 4. Crear Integración
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --integration-type AWS_PROXY \
    --integration-uri "$LAMBDA_ARN" \
    --payload-format-version 2.0 \
    --query 'IntegrationId' --output text)

# 5. Crear Rutas (POST, GET, PUT, DELETE)
declare -a ROUTES=("POST /card" "GET /card" "PUT /card/{id}" "DELETE /card/{id}")
for ROUTE in "${ROUTES[@]}"; do
    aws apigatewayv2 create-route \
        --api-id "$API_ID" \
        --route-key "$ROUTE" \
        --target "integrations/$INTEGRATION_ID"
done

# 6. Permisos para que el API pueda invocar a la Lambda
aws lambda add-permission \
    --function-name "$LAMBDA_NAME" \
    --statement-id "apigateway-invoke" \
    --action "lambda:InvokeFunction" \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:$(aws sts get-caller-identity --query Account --output text):$API_ID/*/*"

# 7. Despliegue (Stage prod)
aws apigatewayv2 create-stage --api-id "$API_ID" --stage-name prod --auto-deploy

echo "------------------------------------------------"
echo "¡Despliegue completado!"
echo "Endpoint base para Postman: https://$API_ID.execute-api.$REGION.amazonaws.com/prod/card"
echo "------------------------------------------------"