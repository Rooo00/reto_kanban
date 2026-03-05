# reto_kanban



¿Qué tecnología elegiste para el cómputo y por qué?
Para el descpliegue y configuración use scripts sh tomande de ejemplo los scripts que usamos para el demo de la clase de hoy de reportGenerator

¿Qué tecnología elegiste para almacenamiento y por qué?
Use dynamoDB para almacenar los datos de las tarjetas de kanban, una base de datos es mejor para almacenar registros de texto como es este ejercicio, una bucket no tiene sentido.


¿Qué tecnologías utilizarías para notificar al usuario que una tarea con estado backlog o doing está próxima a vencer (por ejemplo, al día siguiente)?

Usaría un EC2 que esté leyendo información de la base de datos y si la tarea es próxima, le mandaría un mensaje por uno de los servicios de AWS como SNS
