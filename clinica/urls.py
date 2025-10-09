from django.urls import path
from . import views
app_name = 'clinica'

urlpatterns = [
# auth
path('login/', views.login_view, name='login'),
path('logout/', views.logout_view, name='logout'),
path('register/', views.register_view, name='register'),

# роут после логина — редирект по роли
path('', views.dashboard, name='dashboard'),

# пациент
path('me/', views.patient_profile, name='patient_profile'),
path('me/mental/', views.patient_mental_state, name='patient_mental_state'),
path('me/recipes/', views.patient_chemical_recipes, name='patient_chemical_recipes'),
path('me/devices/', views.patient_mechanical_compounds, name='patient_mechanical_compounds'),
path('me/awareness/', views.patient_awareness, name='patient_awareness'),
path('me/nightmare/', views.patient_nightmare, name='patient_nightmare'),

# врач
path('doctor/me/', views.doctor_profile, name='doctor_profile'),
path('doctor/patients/', views.doctor_patients, name='doctor_patients'),
path('doctor/patients/<int:patient_id>/', views.doctor_patient_detail, name='doctor_patient_detail'),
path('doctor/patients/<int:patient_id>/awareness/', views.doctor_patient_awareness_edit, name='doctor_patient_awareness_edit'),
path('doctor/patients/<int:patient_id>/nightmare/', views.doctor_patient_nightmare_edit, name='doctor_patient_nightmare_edit'),
path('doctor/recipes/', views.doctor_chemical_recipes, name='doctor_chemical_recipes'),
path('doctor/devices/', views.doctor_mechanical_compounds, name='doctor_mechanical_compounds')]