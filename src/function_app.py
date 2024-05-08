import azure.functions as func
import logging
import json
import os
import time

from azure.data.tables import TableServiceClient,TableClient

from typing import Any, Dict

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

entity1: Dict[str, Any] = {
        "PartitionKey" : "pk",
        "RowKey" : "counter",
        "count" : 0,
    }
#connectionString = (os.getenv('CosmosConnectionString'))
connectionString = "DefaultEndpointsProtocol=https;AccountName=panduhz-counter-cosmosdb-test;AccountKey=meVFC6fT1Ochy8mWyD38ykrymABmInb2VcfeNY6dCnI0I8T4tMthGZ5XmroGA6tRqjqt1Uer54bzACDb4a2X9Q==;TableEndpoint=https://panduhz-counter-cosmosdb-test.table.cosmos.azure.com:443/;"

# Global variable to track the last update time
last_update_time = 0

# Delay in seconds for debounce
debounce_delay = 1

# Update count function
def update_count():
    from azure.core.exceptions import ResourceExistsError
    global entity1
    with TableClient.from_connection_string(conn_str=connectionString, table_name="azurerm") as table_client:
        try:
            table_client.create_table()
        except ResourceExistsError:
            logging.info("Table already exists")
        try:
            table_client.create_entity(entity=entity1)
            entity1["count"] = entity1["count"] + 1
        except ResourceExistsError:
            entityCount = table_client.get_entity(partition_key="pk", row_key="counter")
            entity1["count"] = entityCount['count'] + 1
            table_client.update_entity(entity=entity1)

# Debounce the updateDB function
def debounced_update_count():
    global last_update_time
    current_time = time.time()
    if current_time - last_update_time > debounce_delay:
        last_update_time = current_time
        update_count()

#GET request
@app.route(route="readDB", auth_level=func.AuthLevel.ANONYMOUS, methods=['GET'])
def readDB(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Received GET request")
    from azure.core.exceptions import ResourceExistsError
    with TableClient.from_connection_string(conn_str=connectionString
                                                      ,table_name = "azurerm") as table_client:
        try: 
            table_client.create_table()
            entityCount = table_client.get_entity(partition_key="pk", row_key="counter")
        except ResourceExistsError:
            try:
                table_client.create_entity(entity=entity1)
            except ResourceExistsError:
                entityCount = table_client.get_entity(partition_key="pk", row_key="counter")
        entityCount = table_client.get_entity(partition_key="pk", row_key="counter")

    response_obj = {
        "message": "Hello from Azure Functions!",
        "count": entityCount["count"]}
    
    # Then, you return a response with JSON content
    return func.HttpResponse(
        json.dumps(response_obj),
        status_code=200,
        mimetype="application/json"
    )

@app.route(route="updateDB", auth_level=func.AuthLevel.ANONYMOUS, methods=['POST'])
def updateDB(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Received POST request")
    debounced_update_count()

    response_obj = {
        "message": "Update request received"
    }

    return func.HttpResponse(
        json.dumps(response_obj),
        status_code=200,
        mimetype="application/json"
    )

# Reference
# https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/cosmos/azure-cosmos/samples/container_management.py#L231
"""def read_DB():
    from azure.core.exceptions import ResourceExistsError
    global entity1
    # creating an entity to insert if entity does not exist
    # initializing tableclient from tableserviceclient
    with TableClient.from_connection_string(conn_str=connectionString
                                                      ,table_name = "azurerm") as table_client:
        try: 
            table_client.create_table()
        except ResourceExistsError:
            logging.info("Table already exists")    
        # Trying to create the entity, if exists update the entity
        try:
            table_client.create_entity(entity=entity1)
            entity1["count"] = entity1["count"] + 1
        except ResourceExistsError:
            # querying count that's already in the table
            entityCount = table_client.get_entity(partition_key="pk", row_key= "counter")
            entity1["count"] = entityCount['count'] + 1
            table_client.update_entity(entity=entity1) 


@app.route(route="http_trigger", auth_level=func.AuthLevel.FUNCTION)
def http_trigger(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')
    read_DB()

    response_obj = {
        "message": "Hello from Azure Functions!",
        "count": entity1["count"]}
    
    # Then, you return a response with JSON content
    return func.HttpResponse(
        json.dumps(response_obj),
        status_code=200,
        mimetype="application/json"
    )"""


    

"""
This returns something on the website

return func.HttpResponse(f"Hello, {name}. This HTTP triggered function executed successfully.")
"""   
  