/**
 * A 5-level self-referential Account hierarchy for the deep-chain load tests:
 * `LEVEL_1` requires a `LEVEL_2` parent (via `Account.ParentId`) and a `User`
 * owner, and so on; `LEVEL_5` has just the owner. So each primary pulls a chain
 * 5 Accounts deep, each 1 wide (its User) - deep *and* wide. Each level is its
 * own flavour key, so the ancestor-cycle guard sees five distinct Providers.
 *
 * `test-support/` only - not shipped.
 */
@IsTest
public class XFTY_HierarchyKeys {
    public static final XFTY_LookupKeyIntf LEVEL_1 = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'level-1');
    public static final XFTY_LookupKeyIntf LEVEL_2 = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'level-2');
    public static final XFTY_LookupKeyIntf LEVEL_3 = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'level-3');
    public static final XFTY_LookupKeyIntf LEVEL_4 = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'level-4');
    public static final XFTY_LookupKeyIntf LEVEL_5 = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'level-5');

    public static XFTY_DummySObjectProviderLookupIntf lookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                LEVEL_1 => new Level(LEVEL_2),
                LEVEL_2 => new Level(LEVEL_3),
                LEVEL_3 => new Level(LEVEL_4),
                LEVEL_4 => new Level(LEVEL_5),
                LEVEL_5 => new Level(null),
                XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider()
        });
    }

    private class Level implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template;

        private Level(XFTY_LookupKeyIntf parentKey) {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Level'))
                    .putRequired(Account.OwnerId, new XFTY_DummyDefaultRelationship(new User()));
            if (parentKey != null) {
                this.template.putRequired(
                        Account.ParentId,
                        new XFTY_DummyDefaultRelationship(parentKey, new Account())
                );
            }
        }

        public SObjectField getPrimaryTargetField() {
            return Account.Id;
        }

        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }

        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }
}
