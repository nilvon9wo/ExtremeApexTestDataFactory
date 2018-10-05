@IsTest
public class SAMPLE_DummyAccountFactoryOutlet implements XFTY_DummySObjectFactoryOutletIntf {
	private static final SObjectField PRIMARY_TARGET_FIELD = Account.Id;
	public static final String DEFAULT_NAME_PREFIX = 'Test Account Name';

    public SObjectField getPrimaryTargetField() {
    	return PRIMARY_TARGET_FIELD;
    }
    
    public XFTY_DummySObjectBundle createBundle(
	    	List<SObject> templateSObjectList, 
	    	XFTY_InsertModeEnum insertMode, 
	    	XFTY_InsertInclusivityEnum inclusivity
	    ) {
    	XFTY_DummySObjectMasterTemplate masterTemplate = new XFTY_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
    		.put(Account.Name, new XFTY_DummyDefaultValueUniqueString(DEFAULT_NAME_PREFIX)); 
    	
    	return XFTY_DummySObjectFactory.createBundle(masterTemplate, templateSObjectList, insertMode, inclusivity);
    }
}