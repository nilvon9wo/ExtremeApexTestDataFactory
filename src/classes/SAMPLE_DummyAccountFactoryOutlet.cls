@IsTest
public class SAMPLE_DummyAccountFactoryOutlet implements TEST_DummySObjectFactoryOutletIntf {
	private static final SObjectField PRIMARY_TARGET_FIELD = Account.Id;
	public static final String DEFAULT_NAME_PREFIX = 'Test Account Name';

    public SObjectField getPrimaryTargetField() {
    	return PRIMARY_TARGET_FIELD;
    }
    
    public TEST_DummySObjectBundle createBundle(
	    	List<SObject> templateSObjectList, 
	    	TEST_InsertModeEnum insertMode, 
	    	TEST_InsertInclusivityEnum inclusivity
	    ) {
    	TEST_DummySObjectMasterTemplate masterTemplate = new TEST_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
    		.put(Account.Name, new TEST_DummyDefaultValueUniqueString(DEFAULT_NAME_PREFIX)); 
    	
    	return TEST_DummySObjectFactory.createBundle(masterTemplate, templateSObjectList, insertMode, inclusivity);
    }
} 