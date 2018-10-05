@IsTest
public class TEST_DummySObjectMasterTemplate {
	public SObjectField primaryTargetField {get; private set;}
    public Map<SObjectField, TEST_DummyDefaultValueIntf> defaultBySObjectFieldMap {get; private set;}
    public Map<SObjectField, TEST_DummyDefaultRelationshipRequired> requiredRelationshipBySObjectFieldMap {get; private set;}
    public Map<SObjectField, TEST_DummyDefaultRelationshipOptional> optionalRelationshipBySObjectFieldMap {get; private set;}

    public TEST_DummySObjectMasterTemplate(
    		SObjectField primaryTargetField,
    		Map<SObjectField, TEST_DummyDefaultValueIntf> defaultBySObjectFieldMap, 
    		Map<SObjectField, TEST_DummyDefaultRelationshipRequired> requiredRelationshipBySObjectFieldMap,
    		Map<SObjectField, TEST_DummyDefaultRelationshipOptional> optionalRelationshipBySObjectFieldMap
    	) {
    	this.primaryTargetField = primaryTargetField;
    	this.defaultBySObjectFieldMap = defaultBySObjectFieldMap;
    	this.requiredRelationshipBySObjectFieldMap = requiredRelationshipBySObjectFieldMap;
    	this.optionalRelationshipBySObjectFieldMap = optionalRelationshipBySObjectFieldMap;
    }
      
    public TEST_DummySObjectMasterTemplate(SObjectField primaryFieldTarget) { 
    	this( 
    		primaryFieldTarget,
    		new Map<SObjectField, TEST_DummyDefaultValueIntf>(), 
    		new Map<SObjectField, TEST_DummyDefaultRelationshipRequired>(),
    		new Map<SObjectField, TEST_DummyDefaultRelationshipOptional>()
    	); 
    } 

    public TEST_DummySObjectMasterTemplate put(SObjectField sObjectField, TEST_DummyDefaultValueIntf valueTemplate) {
    	this.defaultBySObjectFieldMap.put(sObjectField, valueTemplate); 
    	return this;
    } 

    public TEST_DummySObjectMasterTemplate put(SObjectField sObjectField, TEST_DummyDefaultRelationshipRequired relationshipTemplate) {
    	this.requiredRelationshipBySObjectFieldMap.put(sObjectField, relationshipTemplate); 
    	return this;
    }

    public TEST_DummySObjectMasterTemplate put(SObjectField sObjectField, TEST_DummyDefaultRelationshipOptional relationshipTemplate) {
    	this.optionalRelationshipBySObjectFieldMap.put(sObjectField, relationshipTemplate); 
    	return this;
    }
} 