from django.urls import path

from .views import home, slug_detail, slugs_list, slugs_stats

urlpatterns = [
    path('', home),
    path('slugs/', slugs_list, name='slugs-list'),
    path('slugs/stats/', slugs_stats, name='slugs-stats'),
    path('slugs/<str:slug_name>/', slug_detail, name='slug-detail'),
]
