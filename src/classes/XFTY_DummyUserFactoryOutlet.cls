@IsTest
public class XFTY_DummyUserFactoryOutlet implements XFTY_DummySObjectFactoryOutletIntf {
	public static final String DEFAULT_FIRST_NAME_PREFIX = 'User First Name';
	public static final String DEFAULT_LAST_NAME_PREFIX = 'User Last Name';
	public static final String DEFAULT_FEDERATION_ID_PREFIX = 'User Federation Id';
	public static final String DEFAULT_EMAIL_PREFIX = 'test.email';
	public static final String DEFAULT_USERNAME_PREFIX = 'test.username';
	public static final String DEFAULT_ALIAS_PREFIX = 'a';
	public static final String DEFAULT_EMAIL_ENCODING = 'ISO-8859-1';
	public static final String DEFAULT_LANGUAGE_LOCAL = 'en_US';
	public static final String DEFAULT_LOCALE_SID = 'en_GB';
	public static final String DEFAULT_TIME_ZONE = 'GMT'; 

	private static final String SYSTEM_ADMIN = 'System Administrator';
	private static final Map<String, Id> PROFILE_ID_BY_PROFILE_NAME_MAP = createProfileIdByProfileNameMap(); 
	private static final Id SYSTEM_ADMIN_ID = PROFILE_ID_BY_PROFILE_NAME_MAP.get(SYSTEM_ADMIN);

	private static final String CEO = 'CEO';
	private static final Map<String, Id> USERROLE_ID_BY_USERROLE_NAME_MAP = createUserRoleIdByUserRoleNameMap(); 
	private static final Id CEO_USERROLE_ID = USERROLE_ID_BY_USERROLE_NAME_MAP.get(CEO);

	private static final SObjectField PRIMARY_TARGET_FIELD = User.Id;
	private static final XFTY_DummySObjectMasterTemplate MASTER_TEMPLATE = new XFTY_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
    		.put(User.Alias, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_ALIAS_PREFIX))
    		.put(User.EmailEncodingKey, new XFTY_DummyDefaultValueExact(DEFAULT_EMAIL_ENCODING))
    		.put(User.Email, new XFTY_DummyDefaultValueUniqueEmail(DEFAULT_EMAIL_PREFIX))
    		.put(User.FederationIdentifier, new XFTY_DummyDefaultValueUniqueString(DEFAULT_FEDERATION_ID_PREFIX))
     		.put(User.FirstName, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_FIRST_NAME_PREFIX))
    		.put(User.LanguageLocaleKey, new XFTY_DummyDefaultValueExact(DEFAULT_LANGUAGE_LOCAL))
    		.put(User.LastName, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_LAST_NAME_PREFIX))
    		.put(User.LocaleSidKey, new XFTY_DummyDefaultValueExact(DEFAULT_LOCALE_SID))
    		.put(User.ProfileId, new XFTY_DummyDefaultValueExact(SYSTEM_ADMIN_ID))
    		.put(User.TimeZoneSidKey, new XFTY_DummyDefaultValueExact(DEFAULT_TIME_ZONE))
    		.put(User.Username, new XFTY_DummyDefaultValueUniqueEmail(DEFAULT_USERNAME_PREFIX));

	private static final Map<Id, User> TEST_USER_BY_PROFILE_MAP = createStandardTestUserByProfileMap();
	public static final User TEST_ADMIN_USER = TEST_USER_BY_PROFILE_MAP.get(SYSTEM_ADMIN_ID);

 
    public SObjectField getPrimaryTargetField() {
    	return PRIMARY_TARGET_FIELD; 
    } 

    public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
    	return MASTER_TEMPLATE; 
    }
    
    public XFTY_DummySObjectBundle createBundle(
	    	List<SObject> templateSObjectList, 
	    	XFTY_InsertModeEnum insertMode, 
	    	XFTY_InsertInclusivityEnum inclusivity
	    ) {
		System.debug('######### MASTER_TEMPLATE: ' + MASTER_TEMPLATE);	    	
		System.debug('######### templateSObjectList: ' + templateSObjectList);	    	
		System.debug('######### insertMode: ' + insertMode);	    	
		System.debug('######### inclusivity: ' + inclusivity);	    	
	    	
    	return XFTY_DummySObjectFactory.createBundle(MASTER_TEMPLATE, templateSObjectList, insertMode, inclusivity);
    }
    
	// Helpers ----------------------------------------------------------------------------------------------

	private static Map<Id, User> createStandardTestUserByProfileMap() {
		List<User> templateUserList = new List<User> {
			new User(ProfileId = SYSTEM_ADMIN_ID)
		}; 

		List<User> userList = (new XFTY_DummyUserFactoryOutlet()).createBundle(
				templateUserList, 
				XFTY_InsertModeEnum.NOW, 
				XFTY_InsertInclusivityEnum.REQUIRED
			).getList(PRIMARY_TARGET_FIELD);

		Map<Id, User> userByProfileId = new Map<Id, User>();
		for (User user : userList) {
			userByProfileId.put(user.ProfileId, user);
		} 
		return userByProfileId;
	} 
	
	private static Map<String, Id> createProfileIdByProfileNameMap() {
		Set<String> profileNameSet = new Set<String>{SYSTEM_ADMIN};
		List<Profile> profileList = [
			SELECT id, name
			FROM Profile
			WHERE name IN :profileNameSet
		]; 
		
		Map<String, Id> profileIdByProfileNameMap = new Map<String, Id>();
		for (Profile profile : profileList) {
			profileIdByProfileNameMap.put(profile.name, profile.id);
		}
		return profileIdByProfileNameMap;
	}

	private static Map<String, Id> createUserRoleIdByUserRoleNameMap() {
		Set<String> userroleNameSet = new Set<String>{CEO};
		List<UserRole> userRoleList = [
			SELECT id, name
			FROM UserRole
			WHERE name IN :userroleNameSet
		]; 
		
		Map<String, Id> userRoleIdByUserRoleNameMap = new Map<String, Id>();
		for (UserRole userRole : userRoleList) { 
			userRoleIdByUserRoleNameMap.put(userRole.name, userRole.id);
		}
		return userRoleIdByUserRoleNameMap;
	}
    
}