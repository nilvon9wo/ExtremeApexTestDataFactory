@IsTest
public class XFTY_DummySObjectMasterTemplate {
    public SObjectField primaryTargetField { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultValueIntf> defaultBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultRelationshipRequired> requiredRelationshipBySObjectFieldMap { get; private set; }
    public Map<SObjectField, XFTY_DummyDefaultRelationshipOptional> optionalRelationshipBySObjectFieldMap { get; private set; }

    public XFTY_DummySObjectMasterTemplate(
            SObjectField primaryTargetField,
            Map<SObjectField, XFTY_DummyDefaultValueIntf> defaultBySObjectFieldMap,
            Map<SObjectField, XFTY_DummyDefaultRelationshipRequired> requiredRelationshipBySObjectFieldMap,
            Map<SObjectField, XFTY_DummyDefaultRelationshipOptional> optionalRelationshipBySObjectFieldMap
    ) {
        this.primaryTargetField = primaryTargetField;
        this.defaultBySObjectFieldMap = defaultBySObjectFieldMap;
        this.requiredRelationshipBySObjectFieldMap = requiredRelationshipBySObjectFieldMap;
        this.optionalRelationshipBySObjectFieldMap = optionalRelationshipBySObjectFieldMap;
    }

    public XFTY_DummySObjectMasterTemplate(SObjectField primaryFieldTarget) {
        this(
                primaryFieldTarget,
                new Map<SObjectField, XFTY_DummyDefaultValueIntf>(),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipRequired>(),
                new Map<SObjectField, XFTY_DummyDefaultRelationshipOptional>()
        );
    }

    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_DummyDefaultValueIntf valueTemplate) {
        this.defaultBySObjectFieldMap.put(sObjectField, valueTemplate);
        return this;
    }

    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_DummyDefaultRelationshipRequired relationshipTemplate) {
        this.requiredRelationshipBySObjectFieldMap.put(sObjectField, relationshipTemplate);
        return this;
    }

    public XFTY_DummySObjectMasterTemplate put(SObjectField sObjectField, XFTY_DummyDefaultRelationshipOptional relationshipTemplate) {
        this.optionalRelationshipBySObjectFieldMap.put(sObjectField, relationshipTemplate);
        return this;
    }

    public XFTY_DummySObjectMasterTemplate remove(SObjectField sObjectField) {
        this.defaultBySObjectFieldMap.remove(sObjectField);
        this.requiredRelationshipBySObjectFieldMap.remove(sObjectField);
        this.optionalRelationshipBySObjectFieldMap.remove(sObjectField);
        return this;
    }
}