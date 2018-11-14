@IsTest
public class XFTY_DummyDefaultRelationshipOptional implements XFTY_DummyDefaultRelationshipIntf {
    private SObject overrideTemplate;

    public XFTY_DummyDefaultRelationshipOptional(SObject overrideTemplate) {
        this.overrideTemplate = overrideTemplate;
    }

    public SObject get() {
        return this.overrideTemplate;
    }
}