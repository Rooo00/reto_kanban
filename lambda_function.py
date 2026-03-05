import boto3
import json
import uuid
import re
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('KanbanCards')

ISO_8601_REGEX = r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"
ALLOWED_STATES = ['backlog', 'doing', 'done']

def validate_card(data, partial=False):
    # Validar Estado
    if 'estado' in data and data['estado'] not in ALLOWED_STATES:
        return False, f"Estado inválido. Valores permitidos: {ALLOWED_STATES}"
    
    # Validar Timestamps ISO 8601 
    for field in ['fecha_limite', 'fecha_creado']:
        if field in data:
            if not re.match(ISO_8601_REGEX, data[field]):
                return False, f"Formato de {field} inválido. Debe ser YYYY-MM-DDTHH:MM:SSZ"
    
    # Validar Longitud
    if not partial:
        if len(data.get('titulo', '')) > 50:
            return False, "El título no debe exceder los 50 caracteres."
        if len(data.get('descripcion', '')) > 500:
            return False, "La descripción no debe exceder los 500 caracteres."
            
    return True, None

def lambda_handler(event, context):
    route_key = event.get('routeKey', '')
    path_params = event.get('pathParameters', {})
    
    try:





        
        # POST /card
        if route_key == "POST /card":
            body = json.loads(event['body'])
            is_valid, error_msg = validate_card(body)
            if not is_valid:
                return {"statusCode": 400, "body": json.dumps({"error": error_msg})}
            
            card_id = str(uuid.uuid4())
            item = {
                'card_id': card_id,
                **body
            }
            table.put_item(Item=item)
            return {"statusCode": 201, "body": json.dumps(item)}







        # GET /card
        elif route_key == "GET /card":
            response = table.scan()
            return {"statusCode": 200, "body": json.dumps(response.get('Items', []))}







        # PUT /card/{id}
        elif route_key == "PUT /card/{id}":
            card_id = path_params.get('id')
            body = json.loads(event['body'])
            
            is_valid, error_msg = validate_card(body, partial=True)
            if not is_valid:
                return {"statusCode": 400, "body": json.dumps({"error": error_msg})}
            
            # Actualización solo de campos permitidos
            table.update_item(
                Key={'card_id': card_id},
                UpdateExpression="set fecha_limite=:f, estado=:s",
                ExpressionAttributeValues={
                    ':f': body['fecha_limite'],
                    ':s': body['estado']
                }
            )
            return {"statusCode": 200, "body": json.dumps({"message": "Actualizado", "id": card_id})}

        # DELETE /card/{id}
        elif route_key == "DELETE /card/{id}":
            card_id = path_params.get('id')
            table.delete_item(Key={'card_id': card_id})
            return {"statusCode": 200, "body": json.dumps({"message": "Eliminado"})}

    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}