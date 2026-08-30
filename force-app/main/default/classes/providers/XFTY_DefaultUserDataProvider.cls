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
                    .put(User.Alias, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_ALIAS_PREFIX))
                    .put(User.EmailEncodingKey, new XFTY_DummyDefaultValueExact(DEFAULT_EMAIL_ENCODING))
                    .put(User.Email, new XFTY_DummyDefaultValueUniqueEmail(DEFAULT_EMAIL_PREFIX))
                    .put(User.FederationIdentifier, new XFTY_DummyDefaultValueUniqueString(DEFAULT_FEDERATION_ID_PREFIX))
                    .put(User.FirstName, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_FIRST_NAME_PREFIX))
                    .put(User.LanguageLocaleKey, new XFTY_DummyDefaultValueExact(DEFAULT_LANGUAGE_LOCAL))
                    .put(User.LastName, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_LAST_NAME_PREFIX))
                    .put(User.LocaleSidKey, new XFTY_DummyDefaultValueExact(DEFAULT_LOCALE_SID))
                    .put(User.ProfileId, new XFTY_DummyDefaultValueExact(profileIdFor(SYSTEM_ADMIN)))
                    .put(User.TimeZoneSidKey, new XFTY_DummyDefaultValueExact(DEFAULT_TIME_ZONE))
                    .put(User.Username, new XFTY_DummyDefaultValueUniqueEmail(DEFAULT_USERNAME_PREFIX));

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
            XFTY_DummySObjectProviderLookupIntf providerLookup,
            List<SObject> templateSObjectList,
            XFTY_InsertModeEnum insertMode,
            XFTY_InsertInclusivityEnum inclusivity
    ) {
        return XFTY_DummySObjectFactory.createBundle(providerLookup, MASTER_TEMPLATE, templateSObjectList, insertMode, inclusivity);
    }

    /** Profile Id for a profile's name (cached), or null if there is no such profile in this org. */
    public static Id profileIdFor(String profileName) {
        if (!PROFILE_ID_BY_NAME.containsKey(profileName)) {
            List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
            PROFILE_ID_BY_NAME.put(profileName, profiles.isEmpty() ? null : profiles[0].Id);
        }
        return PROFILE_ID_BY_NAME.get(profileName);
    }

    /** UserRole Id for a role's API (developer) name (cached), or null if there is no such role in this org. */
    public static Id roleIdFor(String roleDeveloperName) {
        if (!ROLE_ID_BY_DEVELOPER_NAME.containsKey(roleDeveloperName)) {
            List<UserRole> roles = [SELECT Id FROM UserRole WHERE DeveloperName = :roleDeveloperName LIMIT 1];
            ROLE_ID_BY_DEVELOPER_NAME.put(roleDeveloperName, roles.isEmpty() ? null : roles[0].Id);
        }
        return ROLE_ID_BY_DEVELOPER_NAME.get(roleDeveloperName);
    }

    // ---------------------------------------------------------------------------

    private static User createStandardAdminUser() {
        return (User) new XFTY_DefaultUserDataProvider().createBundle(
                DEFAULT_SOBJECT_PROVIDER_LOOKUP,
                new List<User>{ new User(ProfileId = profileIdFor(SYSTEM_ADMIN)) },
                XFTY_InsertModeEnum.NOW,
                XFTY_InsertInclusivityEnum.REQUIRED
        ).getList(PRIMARY_TARGET_FIELD)[0];
    }
}
