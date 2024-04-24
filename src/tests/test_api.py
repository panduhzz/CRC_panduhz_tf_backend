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
        response = context.get("https://backend-function-app-test.azurewebsites.net/api/readDB")
        assert response.ok and response.status == 200

def test_get_response():
    with sync_playwright() as p:
        context = p.request.new_context()
        response = context.get("https://backend-function-app-test.azurewebsites.net/api/readDB")
        json_data = json.loads(response.body())
        assert is_number(json_data["count"]), f"Expected 'count' to be an integer, but got {type(json_data['count'])}."