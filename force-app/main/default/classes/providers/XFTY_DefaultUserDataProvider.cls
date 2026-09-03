/**
 * The bundled User Provider, plus a ready-made admin test user
 * ({@link #TEST_ADMIN_USER}) and cached Profile / UserRole Id lookups for tests
 * that need a specific profile or a position in the role hierarchy:
 *
 * ```apex
 * User regionalMgr = (User) new XFTY_DummySObjectProvider(User.SObjectType, lookup)
 *     .setOverrideTemplate(new User(
 *         ProfileId  = XFTY_DefaultUserDataProvider.profileIdFor('Standard User'),
 *         UserRoleId = XFTY_DefaultUserDataProvider.roleIdFor('Regional_Manager')
 *     ))
 *     .setInsertMode(XFTY_InsertModeEnum.NOW)
 *     .supply();
 * ```
 *
 * `profileIdFor(...)` / `roleIdFor(...)` throw `UnknownReferenceException` when the
 * org has no such Profile / UserRole. They are accessors - a caller asking for an
 * Id it then relies on should hear about a missing one immediately, not receive a
 * null that surfaces later as an opaque DML error.
 *
 * `Username` and `FederationIdentifier` use {@link XFTY_UniqueAcrossRunsExpression},
 * not the transaction-scoped counter - the platform requires them globally unique,
 * so a *persisted* User (e.g. from `XFTY_Seeder`) must not repeat a previous run's.
 */
@IsTest
public class XFTY_DefaultUserDataProvider implements XFTY_DummySobjectProviderIntf {
    public static final String DEFAULT_FIRST_NAME_PREFIX = 'User First Name';
    public static final String DEFAULT_LAST_NAME_PREFIX = 'User Last Name';
    public static final String DEFAULT_FEDERATION_ID_PREFIX = 'User Federation Id';
    public static final String DEFAULT_EMAIL_PREFIX = 'test.email';
    public static final String DEFAULT_USERNAME_PREFIX = 'test.username.example';
    public static final String DEFAULT_ALIAS_PREFIX = 'a';
    public static final String DEFAULT_EMAIL_ENCODING = 'ISO-8859-1';
    public static final String DEFAULT_LANGUAGE_LOCAL = 'en_US';
    public static final String DEFAULT_LOCALE_SID = 'en_GB';
    public static final String DEFAULT_TIME_ZONE = 'GMT';

    public static final String SYSTEM_ADMIN = 'System Administrator';

    private static final Map<String, Id> PROFILE_ID_BY_NAME = new Map<String, Id>();
    private static final Map<String, Id> ROLE_ID_BY_DEVELOPER_NAME = new Map<String, Id>();

    private static final SObjectField PRIMARY_TARGET_FIELD = User.Id;
    private static final XFTY_DummySObjectMasterTemplate MASTER_TEMPLATE
            = new XFTY_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
                    .put(User.Alias, new XFTY_IncrementingStringExpression(DEFAULT_ALIAS_PREFIX))
                    .put(User.EmailEncodingKey, new XFTY_LiteralExpression(DEFAULT_EMAIL_ENCODING))
                    .put(User.Email, new XFTY_UniqueEmailExpression(DEFAULT_EMAIL_PREFIX))
                    .put(User.FederationIdentifier, new XFTY_UniqueAcrossRunsExpression(DEFAULT_FEDERATION_ID_PREFIX + ' ', ''))
                    .put(User.FirstName, new XFTY_IncrementingStringExpression(DEFAULT_FIRST_NAME_PREFIX))
                    .put(User.LanguageLocaleKey, new XFTY_LiteralExpression(DEFAULT_LANGUAGE_LOCAL))
                    .put(User.LastName, new XFTY_IncrementingStringExpression(DEFAULT_LAST_NAME_PREFIX))
                    .put(User.LocaleSidKey, new XFTY_LiteralExpression(DEFAULT_LOCALE_SID))
                    .put(User.ProfileId, new XFTY_LiteralExpression(profileIdFor(SYSTEM_ADMIN)))
                    .put(User.TimeZoneSidKey, new XFTY_LiteralExpression(DEFAULT_TIME_ZONE))
                    .put(User.Username, new XFTY_UniqueAcrossRunsExpression(DEFAULT_USERNAME_PREFIX + '.', '@example.com'));

    private static final XFTY_DummySObjectProviderLookupIntf DEFAULT_SOBJECT_PROVIDER_LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    /** An inserted System Administrator user, for `System.runAs(...)`. */
    public static final User TEST_ADMIN_USER = createStandardAdminUser();

    public SObjectField getPrimaryTargetField() {
        return PRIMARY_TARGET_FIELD;
    }

    public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
        return MASTER_TEMPLATE;
    }

    public XFTY_DummySObjectBundle createBundle(
            XFTY_GenerationContext context,
            List<SObject> templateSObjectList
    ) {
        return XFTY_DummySObjectFactory.createBundle(context, MASTER_TEMPLATE, templateSObjectList);
    }

    /**
     * Profile Id for a profile's name (cached across the transaction).
     * @throws UnknownReferenceException if this org has no Profile with that name.
     */
    public static Id profileIdFor(String profileName) {
        if (!PROFILE_ID_BY_NAME.containsKey(profileName)) {
            List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
            if (profiles.isEmpty()) {
                throw new UnknownReferenceException(
                        'No Profile named "' + profileName + '" exists in this org. '
                                + 'profileIdFor(...) takes the Profile label, not its API name.'
                );
            }
            PROFILE_ID_BY_NAME.put(profileName, profiles[0].Id);
        }
        return PROFILE_ID_BY_NAME.get(profileName);
    }

    /**
     * UserRole Id for a role's API (developer) name (cached across the transaction).
     * @throws UnknownReferenceException if this org has no UserRole with that developer name.
     */
    public static Id roleIdFor(String roleDeveloperName) {
        if (!ROLE_ID_BY_DEVELOPER_NAME.containsKey(roleDeveloperName)) {
            List<UserRole> roles = [SELECT Id FROM UserRole WHERE DeveloperName = :roleDeveloperName LIMIT 1];
            if (roles.isEmpty()) {
                throw new UnknownReferenceException(
                        'No UserRole with DeveloperName "' + roleDeveloperName + '" exists in this org. '
                                + 'Create the role, or check the developer (API) name.'
                );
            }
            ROLE_ID_BY_DEVELOPER_NAME.put(roleDeveloperName, roles[0].Id);
        }
        return ROLE_ID_BY_DEVELOPER_NAME.get(roleDeveloperName);
    }

    public class UnknownReferenceException extends Exception {
    }

    // ---------------------------------------------------------------------------

    private static User createStandardAdminUser() {
        return (User) new XFTY_DefaultUserDataProvider().createBundle(
                new XFTY_GenerationContext(
                        DEFAULT_SOBJECT_PROVIDER_LOOKUP,
                        XFTY_InsertModeEnum.NOW,
                        XFTY_InsertInclusivityEnum.REQUIRED
                ),
                new List<User>{ new User(ProfileId = profileIdFor(SYSTEM_ADMIN)) }
        ).getList(PRIMARY_TARGET_FIELD)[0];
    }
}
