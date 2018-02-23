# source:
# https://gist.github.com/Yogendra0Sharma/2469152037f7560c148368ee8de27c3a


from django_auth_ldap.backend import LDAPBackend, _LDAPUser


class LDAPUsernameBackend(LDAPBackend):
    settings_prefix = "AUTH_LDAP_U_"


class LDAPEmailBackend(LDAPBackend):
    settings_prefix = "AUTH_LDAP_E_"

    def get_or_create_user(self, email, ldap_user):
        """
        Use the Posixuser uid field as username instead of form value (email).

        This must return a (User, created) 2-tuple for the given LDAP user.
        username is the Django-friendly username of the user. ldap_user.dn is
        the user's DN and ldap_user.attrs contains all of their LDAP attributes.
        """
        model = self.get_user_model()
        username_field = getattr(model, 'USERNAME_FIELD', 'username')

        kwargs = {
            username_field + '__iexact': ldap_user.attrs['uid'][0],
            'defaults': {
                username_field: ldap_user.attrs['uid'][0].lower(),
                'email': email
            }
        }

        return model.objects.get_or_create(**kwargs)
