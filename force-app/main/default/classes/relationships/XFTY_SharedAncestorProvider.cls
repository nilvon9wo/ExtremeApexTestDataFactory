/**
 * How a shared ancestor's one record is described and built - the recipe
 * {@link XFTY_SharedAncestorResolver} works from, so the resolver never branches
 * on which kind of configuration a shared ancestor carries.
 *
 * Two implementations:
 *
 * - {@link XFTY_KeyedAncestorProvider} - a lookup key and/or an override
 *   template (`XFTY_SharedAncestor.of(...)` / `.withKey(...)`).
 * - {@link XFTY_ConfiguredAncestorProvider} - a fully-configured
 *   `XFTY_DummySObjectProvider` (`XFTY_SharedAncestor.suppliedBy(...)`).
 *
 * `lookup` is the Provider Lookup of the generation run that triggered
 * resolution; an implementation that carries its own lookup ignores it.
 */
public interface XFTY_SharedAncestorProvider {

    /** This ancestor's whole graph, generated with no persistence, ready for the depth-batched insert. */
    XFTY_DummySObjectBundle buildInMemory(XFTY_DummySObjectProviderLookupIntf lookup);

    /** The primary target field (the record's `Id` field) of {@link #buildInMemory}'s bundle. */
    SObjectField primaryField(XFTY_DummySObjectProviderLookupIntf lookup);

    /** The Master Template the pre-phase scans for nested shared ancestors. */
    XFTY_DummySObjectMasterTemplate masterTemplate(XFTY_DummySObjectProviderLookupIntf lookup);

    /** The lookup key this ancestor resolves under. */
    XFTY_LookupKeyIntf lookupKey(XFTY_DummySObjectProviderLookupIntf lookup);
}
