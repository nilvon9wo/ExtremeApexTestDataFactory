@IsTest
public class SAMPLE_DummyContactFactoryOutlet implements TEST_DummySObjectFactoryOutletIntf {
	private static final SObjectField PRIMARY_TARGET_FIELD = Contact.Id;
	public static final String DEFAULT_FIRST_NAME_PREFIX = 'Contact First Name';
	public static final String DEFAULT_LAST_NAME_PREFIX = 'Contact Last Name';
	public static final String DEFAULT_EMAIL_PREFIX = 'test.contact';

    public SObjectField getPrimaryTargetField() {
    	return PRIMARY_TARGET_FIELD;
    }
    
    public TEST_DummySObjectBundle createBundle(
	    	List<SObject> templateSObjectList, 
	    	TEST_InsertModeEnum insertMode, 
	    	TEST_InsertInclusivityEnum inclusivity
	    ) {
    	TEST_DummySObjectMasterTemplate masterTemplate = new TEST_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
    		.put(Contact.FirstName, new TEST_DummyDefaultValueIncrementingString(DEFAULT_FIRST_NAME_PREFIX))
    		.put(Contact.LastName, new TEST_DummyDefaultValueIncrementingString(DEFAULT_LAST_NAME_PREFIX))
    		.put(Contact.Email, new TEST_DummyDefaultValueUniqueEmail(DEFAULT_EMAIL_PREFIX))
    		.put(Contact.AccountId, new TEST_DummyDefaultRelationshipRequired(new Account(
    			Description = 'Account for contact'
    		)));
    	return TEST_DummySObjectFactory.createBundle(masterTemplate, templateSObjectList, insertMode, inclusivity);
    }
} 