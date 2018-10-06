//@IsTest
public interface XFTY_DummySObjectFactoryOutletIntf {
    SObjectField getPrimaryTargetField();
    XFTY_DummySObjectMasterTemplate getMasterTemplate();
    
    XFTY_DummySObjectBundle createBundle(
    	List<SObject> templateSObjectList, 
    	XFTY_InsertModeEnum insertMode,  
    	XFTY_InsertInclusivityEnum inclusivity
    );
}