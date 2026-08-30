//@IsTest
public interface XFTY_DummySobjectProviderIntf {
    SObjectField getPrimaryTargetField();
    XFTY_DummySObjectMasterTemplate getMasterTemplate();

    XFTY_DummySObjectBundle createBundle(
            XFTY_GenerationContext context,
            List<SObject> templateSObjectList
    );
}
