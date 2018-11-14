@IsTest
public class XFTY_SMPL_DummyContactFactoryOutlet implements XFTY_DummySObjectFactoryOutletIntf {
    public static final String DEFAULT_FIRST_NAME_PREFIX = 'Contact First Name';
    public static final String DEFAULT_LAST_NAME_PREFIX = 'Contact Last Name';
    public static final String DEFAULT_EMAIL_PREFIX = 'test.contact';
    public static final String DEFAULT_ACCOUNT_DESCRIPTION = 'Account for contact';

    private static final SObjectField PRIMARY_TARGET_FIELD = Contact.Id;
    private static final XFTY_DummySObjectMasterTemplate MASTER_TEMPLATE = new XFTY_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
            .put(Contact.FirstName, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_FIRST_NAME_PREFIX))
            .put(Contact.LastName, new XFTY_DummyDefaultValueIncrementingString(DEFAULT_LAST_NAME_PREFIX))
            .put(Contact.Email, new XFTY_DummyDefaultValueUniqueEmail(DEFAULT_EMAIL_PREFIX))
            .put(Contact.AccountId, new XFTY_DummyDefaultRelationshipRequired(new Account(
                    Description = DEFAULT_ACCOUNT_DESCRIPTION
            )));

    public SObjectField getPrimaryTargetField() {
        return PRIMARY_TARGET_FIELD;
    }

    public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
        return MASTER_TEMPLATE;
    }

    public XFTY_DummySObjectBundle createBundle(
            List<SObject> templateSObjectList,
            XFTY_InsertModeEnum insertMode,
            XFTY_InsertInclusivityEnum inclusivity
    ) {
        return XFTY_DummySObjectFactory.createBundle(MASTER_TEMPLATE, templateSObjectList, insertMode, inclusivity);
    }
}