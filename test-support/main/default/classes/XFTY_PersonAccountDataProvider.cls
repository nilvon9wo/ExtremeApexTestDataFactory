/**
 * A worked example of a record-type Provider variant: Person Accounts.
 *
 * Lives in `test-support/` (not the published package) because Person Accounts
 * is an org feature that not every consumer has and that XFTY must not force.
 * Register it under `XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'PersonAccount')`
 * alongside `XFTY_DefaultAccountDataProvider` for the business record type.
 */
@IsTest
public class XFTY_PersonAccountDataProvider implements XFTY_DummySobjectProviderIntf {
    public static final String RECORD_TYPE_DEVELOPER_NAME = 'PersonAccount';
    public static final String DEFAULT_LAST_NAME_PREFIX = 'XFTY Person Account';
    public static final String DEFAULT_EMAIL_PREFIX = 'xfty.person.account';

    private static final SObjectField PRIMARY_TARGET_FIELD = Account.Id;

    private static final XFTY_DummySObjectMasterTemplate MASTER_TEMPLATE
            = new XFTY_DummySObjectMasterTemplate(PRIMARY_TARGET_FIELD)
                    .put(Account.RecordTypeId, new XFTY_LiteralExpression(
                            XFTY_RecordTypeMatching.idFor(Account.SObjectType, RECORD_TYPE_DEVELOPER_NAME)))
                    .put(Account.LastName, new XFTY_IncrementingStringExpression(DEFAULT_LAST_NAME_PREFIX))
                    .put(Account.PersonEmail, new XFTY_UniqueEmailExpression(DEFAULT_EMAIL_PREFIX));

    public SObjectField getPrimaryTargetField() {
        return PRIMARY_TARGET_FIELD;
    }

    public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
        return MASTER_TEMPLATE;
    }

    public XFTY_DummySObjectBundle createBundle(
            XFTY_GenerationContext context,
            List<SObject> templateSObjectList
    ) {
        return XFTY_DummySObjectFactory.createBundle(context, MASTER_TEMPLATE, templateSObjectList);
    }
}
