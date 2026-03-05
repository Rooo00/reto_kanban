import boto3
import json
import uuid
import re

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("KanbanCards")

ISO_8601_REGEX = r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"
ALLOWED_STATES = ["backlog", "doing", "done"]


def validate_card(data, partial=False):
    if "estado" in data and data["estado"] not in ALLOWED_STATES:
        return False, f"Estado inválido. Valores permitidos: {ALLOWED_STATES}"

    for f in ["fecha_limite", "fecha_creado"]:
        if f in data and not re.match(ISO_8601_REGEX, data[f]):
            return False, f"Formato de {f} inválido. Debe ser YYYY-MM-DDTHH:MM:SSZ"

    if not partial:
        if len(data.get("titulo", "")) > 50:
            return False, "El título no debe exceder los 50 caracteres."
        if len(data.get("descripcion", "")) > 500:
            return False, "La descripción no debe exceder los 500 caracteres."

    return True, None


def lambda_handler(event, context):
    route = event.get("routeKey", "")
    params = event.get("pathParameters", {})

    try:
        if route == "POST /card":
            body = json.loads(event["body"])
            ok, err = validate_card(body)
            if not ok:
                return {"statusCode": 400, "body": json.dumps({"error": err})}

            item = {"card_id": str(uuid.uuid4()), **body}
            table.put_item(Item=item)
            return {"statusCode": 201, "body": json.dumps(item)}

        if route == "GET /card":
            res = table.scan()
            return {"statusCode": 200, "body": json.dumps(res.get("Items", []))}

        if route == "PUT /card/{id}":
            card_id = params.get("id")
            body = json.loads(event["body"])

            ok, err = validate_card(body, partial=True)
            if not ok:
                return {"statusCode": 400, "body": json.dumps({"error": err})}

            table.update_item(
                Key={"card_id": card_id},
                UpdateExpression="set fecha_limite=:f, estado=:s",
                ExpressionAttributeValues={
                    ":f": body["fecha_limite"],
                    ":s": body["estado"],
                },
            )
            return {
                "statusCode": 200,
                "body": json.dumps({"message": "Actualizado", "id": card_id}),
            }

        if route == "DELETE /card/{id}":
            card_id = params.get("id")
            table.delete_item(Key={"card_id": card_id})
            return {"statusCode": 200, "body": json.dumps({"message": "Eliminado"})}

    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}