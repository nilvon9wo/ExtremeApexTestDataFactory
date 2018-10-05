@IsTest
public class TEST_DummyDefaultRelationshipRequired implements TEST_DummyDefaultRelationshipIntf {
    private SObject overrideTemplate;
    
    public TEST_DummyDefaultRelationshipRequired(SObject overrideTemplate) {
    	this.overrideTemplate = overrideTemplate;
    } 
    
    public SObject get() {
    	return this.overrideTemplate; 
    } 
}  