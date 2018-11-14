@IsTest
public class XFTY_DummyDefaultRelationshipRequired implements XFTY_DummyDefaultRelationshipIntf {
    private SObject overrideTemplate;

    public XFTY_DummyDefaultRelationshipRequired(SObject overrideTemplate) {
        this.overrideTemplate = overrideTemplate;
    }

    public SObject get() {
        return this.overrideTemplate;
    }
}