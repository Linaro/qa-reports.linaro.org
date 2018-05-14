# source:
# https://gist.github.com/Yogendra0Sharma/2469152037f7560c148368ee8de27c3a


from django_auth_ldap.backend import LDAPBackend, _LDAPUser


class LDAPUsernameBackend(LDAPBackend):
    settings_prefix = "AUTH_LDAP_U_"


class LDAPEmailBackend(LDAPBackend):
    settings_prefix = "AUTH_LDAP_E_"
