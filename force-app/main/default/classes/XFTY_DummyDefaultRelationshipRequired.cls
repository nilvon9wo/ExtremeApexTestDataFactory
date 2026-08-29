@IsTest
public class XFTY_DummyDefaultRelationshipRequired implements XFTY_DummyDefaultRelationshipIntf {
    private final SObject overrideTemplate;
    private final SObjectField relatedField;

    public XFTY_DummyDefaultRelationshipRequired(SObject overrideTemplate, SObjectField relatedField) {
        this.overrideTemplate = overrideTemplate;
        this.relatedField = relatedField;
    }

    public XFTY_DummyDefaultRelationshipRequired(SObject overrideTemplate) {
        this(overrideTemplate, null);
    }

    public SObject getOverrideTemplate() {
        return this.overrideTemplate;
    }

    public SObjectField getRelatedField() {
        return this.relatedField;
    }
}