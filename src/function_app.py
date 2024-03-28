import azure.functions as func
import logging
import json
import os

from azure.data.tables import TableServiceClient,TableClient

from typing import Any, Dict

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

entity1: Dict[str, Any] = {
        "PartitionKey" : "pk",
        "RowKey" : "counter",
        "count" : 0,
    }

# Reference
# https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/cosmos/azure-cosmos/samples/container_management.py#L231
def read_DB():
    from azure.core.exceptions import ResourceExistsError
    global entity1
    # creating an entity to insert if entity does not exist
    
    connectionString = (os.getenv('CosmosConnectionString'))

    

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
    )


    

"""
This returns something on the website

return func.HttpResponse(f"Hello, {name}. This HTTP triggered function executed successfully.")
"""   
  