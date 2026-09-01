/**
 * A shared ancestor described by a lookup key and/or an override template -
 * `XFTY_SharedAncestor.putAsTemplate(name, template)` / `put(name, key)` /
 * `.fromVariant(key)`. The record is
 * built by the Provider the key resolves to (or the key derived from the
 * template), exactly as an ordinary generated parent would be.
 */
@IsTest
public class XFTY_KeyedAncestorProvider implements XFTY_SharedAncestorProvider {

    private final String ancestorName;
    private SObject overrideTemplate;
    private XFTY_LookupKeyIntf explicitKey;
    private XFTY_LookupKeyIntf resolvedKey;

    public XFTY_KeyedAncestorProvider(String ancestorName) {
        this.ancestorName = ancestorName;
    }

    public XFTY_KeyedAncestorProvider withTemplate(SObject overrideTemplate) {
        this.overrideTemplate = overrideTemplate;
        return this;
    }

    public XFTY_KeyedAncestorProvider withKey(XFTY_LookupKeyIntf key) {
        this.explicitKey = key;
        return this;
    }

    /** The override template, if `of(...)` supplied one - for `XFTY_DummyDefaultRelationshipIntf`. */
    public SObject overrideTemplate() {
        return this.overrideTemplate;
    }

    public XFTY_DummySObjectBundle buildInMemory(XFTY_DummySObjectProviderLookupIntf lookup) {
        XFTY_GenerationContext structuralContext = new XFTY_GenerationContext(
                lookup, XFTY_InsertModeEnum.NEVER, XFTY_InsertInclusivityEnum.REQUIRED
        );
        return this.provider(lookup).createBundle(
                structuralContext,
                new List<SObject>{ this.recordTemplate(lookup).clone(true, true, true, true) }
        );
    }

    public SObjectField primaryField(XFTY_DummySObjectProviderLookupIntf lookup) {
        return this.provider(lookup).getPrimaryTargetField();
    }

    public XFTY_DummySObjectMasterTemplate masterTemplate(XFTY_DummySObjectProviderLookupIntf lookup) {
        return this.provider(lookup).getMasterTemplate();
    }

    public XFTY_LookupKeyIntf lookupKey(XFTY_DummySObjectProviderLookupIntf lookup) {
        if (this.resolvedKey == null) {
            this.resolvedKey = (this.explicitKey != null)
                    ? this.explicitKey
                    : XFTY_ProviderLookups.resolve(lookup, this.requireTemplate());
        }
        return this.resolvedKey;
    }

    private XFTY_DummySobjectProviderIntf provider(XFTY_DummySObjectProviderLookupIntf lookup) {
        return lookup.get(this.lookupKey(lookup));
    }

    private SObject recordTemplate(XFTY_DummySObjectProviderLookupIntf lookup) {
        return (this.overrideTemplate != null)
                ? this.overrideTemplate
                : this.lookupKey(lookup).getSObjectType().newSObject();
    }

    private SObject requireTemplate() {
        if (this.overrideTemplate == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.ancestorName + '" needs putAsTemplate(name, template) '
                            + 'or put(name, key) before it can resolve.'
            );
        }
        return this.overrideTemplate;
    }
}
