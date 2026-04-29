from django.urls import path

from .views import healthz, home, slug_detail, slugs_duel, slugs_list, slugs_stats

urlpatterns = [
    path('', home),
    path('healthz/', healthz, name='healthz'),
    path('slugs/', slugs_list, name='slugs-list'),
    path('slugs/stats/', slugs_stats, name='slugs-stats'),
    path('slugs/duel/', slugs_duel, name='slugs-duel'),
    path('slugs/<str:slug_name>/', slug_detail, name='slug-detail'),
]
