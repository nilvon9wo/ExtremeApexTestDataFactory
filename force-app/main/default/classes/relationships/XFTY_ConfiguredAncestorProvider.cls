/**
 * A shared ancestor described by a fully-configured `XFTY_DummySObjectProvider` -
 * `XFTY_SharedAncestor.get(name).suppliedBy(provider)`. The whole generation API
 * (value strategies, relationship control, path values, a pinned variant) shapes
 * the one shared record; the Provider carries its own override template and
 * Provider Lookup.
 */
@IsTest
public class XFTY_ConfiguredAncestorProvider implements XFTY_SharedAncestorProvider {

    private final XFTY_DummySObjectProvider provider;

    public XFTY_ConfiguredAncestorProvider(XFTY_DummySObjectProvider provider) {
        if (provider == null) {
            throw new XFTY_DummySObjectFtyProviderException('suppliedBy(...) needs an XFTY_DummySObjectProvider.');
        }
        this.provider = provider;
    }

    public XFTY_DummySObjectBundle buildInMemory(XFTY_DummySObjectProviderLookupIntf lookup) {
        this.provider.assertUsableAsSharedAncestorSource();
        return this.provider.buildStructurally();
    }

    public SObjectField primaryField(XFTY_DummySObjectProviderLookupIntf lookup) {
        return this.provider.primaryTargetField();
    }

    public XFTY_DummySObjectMasterTemplate masterTemplate(XFTY_DummySObjectProviderLookupIntf lookup) {
        return this.provider.effectiveMasterTemplate();
    }

    public XFTY_LookupKeyIntf lookupKey(XFTY_DummySObjectProviderLookupIntf lookup) {
        return XFTY_LookupKey.get(this.provider.targetSObjectType());
    }
}
