import pytest

from playwright.sync_api import sync_playwright, Playwright
import playwright
from azure.data.tables import TableClient
import os
import json

def is_number(s):
    """ Returns True if the string s is a number. """
    try:
        float(s)  # for int, float and complex
    except ValueError:
        return False
    return True

#test get request
def test_get_request_status():
    with sync_playwright() as p:
        context = p.request.new_context()
        response = context.get("https://panduhz-backend-app-test.azurewebsites.net/api/readDB")
        assert response.ok and response.status == 200

def test_get_response():
    with sync_playwright() as p:
        context = p.request.new_context()
        response = context.get("https://panduhz-backend-app-test.azurewebsites.net/api/readDB")
        json_data = json.loads(response.body())
        assert is_number(json_data["count"]), f"Expected 'count' to be an integer, but got {type(json_data['count'])}."

#test post request
def test_post_update():
    with sync_playwright() as p:
        context = p.request.new_context()
        response = context.post("https://panduhz-backend-app-test.azurewebsites.net/api/updateDB")
        json_data = json.loads(response.body())
        initialCount = json_data["updatedCount"]
        response = context.post("https://panduhz-backend-app-test.azurewebsites.net/api/updateDB")
        json_data = json.loads(response.body())
        count = json_data["updatedCount"]
        assert count > initialCount, "Did not update as expected"

def test_post_request_status():
    with sync_playwright() as p:
        context = p.request.new_context()
        response = context.post("https://panduhz-backend-app-test.azurewebsites.net/api/updateDB")
        assert response.ok and response.status == 200
