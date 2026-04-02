from django.shortcuts import render
from rest_framework.decorators import api_view
from rest_framework.response import Response
# Create your views here.

@api_view(['Get'])
def home(request):
    return Response("Welcome, This is the home page of Slugterra API.")