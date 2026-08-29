//@IsTest
public interface XFTY_DummySobjectProviderIntf {
    SObjectField getPrimaryTargetField();
    XFTY_DummySObjectMasterTemplate getMasterTemplate();

    XFTY_DummySObjectBundle createBundle(
            XFTY_DummySObjectProviderLookupIntf providerLookup,
            List<SObject> templateSObjectList,
            XFTY_InsertModeEnum insertMode,
            XFTY_InsertInclusivityEnum inclusivity
    );
}