/**
 * A Provider Lookup for the load tests: the three bundled Providers plus a
 * minimal `Task` Provider, so a "wide graph" test can hang a `Task` off an
 * `Account` and a `Contact` at once.
 *
 * `test-support/` only.
 */
@IsTest
public class XFTY_LoadProviders {

    public static XFTY_DummySObjectProviderLookupIntf lookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider(),
                XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider(),
                XFTY_LookupKey.get(Task.SObjectType) => new TaskProvider()
        });
    }

    private class TaskProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Task.Id)
                .put(Task.Subject, new XFTY_DummyDefaultValueIncrementingString('Load Task'));

        public SObjectField getPrimaryTargetField() {
            return Task.Id;
        }

        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }

        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }
}
