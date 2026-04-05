from django.urls import path
from .views import *

urlpatterns = [
    path('', home),
    path('slugs/', slugs_list, name='slugs-list'),
    path('slugs/<str:slug_name>/', slug_detail, name='slug-detail'),
]
