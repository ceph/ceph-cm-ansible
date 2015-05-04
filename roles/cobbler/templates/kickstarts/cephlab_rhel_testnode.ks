{% extends 'cephlab_rhel.ks' %}
{% block user_setup %}
$SNIPPET('cephlab_user_testnode')
{% endblock %}
