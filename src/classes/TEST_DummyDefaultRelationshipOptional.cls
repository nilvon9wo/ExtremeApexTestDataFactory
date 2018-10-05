@IsTest 
public class TEST_DummyDefaultRelationshipOptional implements TEST_DummyDefaultRelationshipIntf {
    private SObject overrideTemplate;
    
    public TEST_DummyDefaultRelationshipOptional(SObject overrideTemplate) {
    	this.overrideTemplate = overrideTemplate;
    } 
    
    public SObject get() {
    	return this.overrideTemplate; 
    } 
} 