//@IsTest
public interface TEST_DummySObjectFactoryOutletIntf {
    SObjectField getPrimaryTargetField();
    
    TEST_DummySObjectBundle createBundle(
    	List<SObject> templateSObjectList, 
    	TEST_InsertModeEnum insertMode, 
    	TEST_InsertInclusivityEnum inclusivity
    );
}