/**
 * One record, shared by every relationship that references it - the same
 * instance and the same Id everywhere, generated at most once per test method.
 *
 * ```apex
 * // configure once, centrally
 * XFTY_SharedAncestor.get('acme-hq').of(new Account(Name = 'ACME HQ'));
 *
 * // reference it from any Master Template, any field
 * new XFTY_DummySObjectMasterTemplate(Contact.Id)
 *     .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('acme-hq'))
 *
 * new XFTY_DummySObjectMasterTemplate(Case.Id)
 *     .putOptional(Case.AccountId, XFTY_SharedAncestor.get('acme-hq'))
 * ```
 *
 * Generate 50 Contacts under one `acme-hq` Account with a single generated
 * Account and (in `NOW` mode) a single Account insert.
 *
 * Flyweight: obtain instances with `get(name)`, never `new`. State is static, so
 * it resets between test methods automatically - each method starts clean and is
 * responsible for its own shared ancestors (Salesforce never shares data between
 * tests). No reset hook is needed or provided.
 *
 * This is the **on-demand** kind (design doc decision 9): lightweight, resolved
 * inline the first time it is referenced, and it must have no ancestors of its
 * own - a shared ancestor that references itself (directly or through its
 * Provider's relationships) throws rather than recursing. Deep / declared
 * ancestors and DML-batched resolution are a later increment - see
 * docs/roadmap/shared-ancestors.md.
 */
@IsTest
public class XFTY_SharedAncestor implements XFTY_SharedRelationshipIntf {
    public enum Kind { ON_DEMAND, DECLARED }

    private static final Map<String, XFTY_SharedAncestor> BY_NAME = new Map<String, XFTY_SharedAncestor>();

    // Declared-ancestor state - static, so it resets between test methods.
    private static final Set<String> REQUIRED_NAMES = new Set<String>();
    private static XFTY_InsertModeEnum declaredMode;
    private static Boolean declaredPhaseComplete = false;

    private final String name;
    private Kind kind = Kind.ON_DEMAND;
    private SObject overrideTemplate;
    private XFTY_LookupKeyIntf explicitLookupKey;
    private SObjectField relatedField;
    private XFTY_LookupKeyIntf resolvedLookupKey;
    private SObject resolvedRecord;
    private XFTY_DummySObjectBundle resolvedBundle;
    private Boolean resolvedRecordIsPersisted = false;
    private Boolean resolutionInProgress = false;

    private XFTY_SharedAncestor(String name) {
        this.name = name;
    }

    /** The interned instance for `name`, creating it on first use. */
    public static XFTY_SharedAncestor get(String name) {
        if (String.isBlank(name)) {
            throw new XFTY_DummySObjectFtyProviderException('A shared ancestor needs a non-blank name.');
        }
        if (!BY_NAME.containsKey(name)) {
            BY_NAME.put(name, new XFTY_SharedAncestor(name));
        }
        return BY_NAME.get(name);
    }

    // Declared ancestors ---------------------------------------------------------
    //
    // A DECLARED ancestor may be deep / heavy / have its own ancestors. It is
    // resolved once, up front, in a batched pre-phase (S0-S2), and only if the
    // test asks for it with require(...). Reaching a declared ancestor the test
    // did not require throws - no silent fallback.

    /**
     * Mark `name` as a **declared** ancestor and return it for `.of(...)` / `.withKey(...)`
     * configuration (do this once, centrally). A test then opts in with `require(name)`.
     */
    public static XFTY_SharedAncestor declared(String name) {
        XFTY_SharedAncestor ancestor = get(name);
        ancestor.kind = Kind.DECLARED;
        return ancestor;
    }

    /** Declare that this test needs these declared ancestors. Call at the top of the test. */
    public static void require(List<String> names) {
        REQUIRED_NAMES.addAll(names);
    }
    public static void require(String name) {
        REQUIRED_NAMES.add(name);
    }
    public static void require(String a, String b) {
        REQUIRED_NAMES.add(a);
        REQUIRED_NAMES.add(b);
    }
    public static void require(String a, String b, String c) {
        require(new List<String>{ a, b, c });
    }
    public static void require(String a, String b, String c, String d) {
        require(new List<String>{ a, b, c, d });
    }

    /**
     * Fix the insert mode the declared ancestors resolve against, before any
     * `supply*()` call has one. Fluent: `XFTY_SharedAncestor.context(NOW).require('root')`.
     */
    public static DeclaredContext context(XFTY_InsertModeEnum insertMode) {
        declaredMode = insertMode;
        return new DeclaredContext();
    }

    public class DeclaredContext {
        public void require(String name) {
            XFTY_SharedAncestor.require(name);
        }
        public void require(String a, String b) {
            XFTY_SharedAncestor.require(a, b);
        }
        public void require(List<String> names) {
            XFTY_SharedAncestor.require(names);
        }
    }

    /**
     * Resolve every required declared ancestor now (S0-S2), against `insertMode`
     * (or the mode set with `context(...)`). Normally the first `supply*()` call
     * triggers this; call it explicitly only when a test reads
     * `getId(declaredName)` before any generation.
     */
    public static void resolveDeclared(XFTY_DummySObjectProviderLookupIntf providerLookup) {
        ensureDeclaredResolved(providerLookup, declaredMode);
    }

    /** Called by the factory before it generates - resolves any pending required declared ancestors. */
    public static void ensureDeclaredResolved(
            XFTY_DummySObjectProviderLookupIntf providerLookup,
            XFTY_InsertModeEnum callInsertMode
    ) {
        if (declaredPhaseComplete || REQUIRED_NAMES.isEmpty()) {
            return;
        }
        XFTY_InsertModeEnum mode = (declaredMode != null) ? declaredMode : callInsertMode;
        if (mode == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Declared shared ancestors need an insert mode. Call '
                            + 'XFTY_SharedAncestor.context(XFTY_InsertModeEnum.NOW).require(...) at the top of the test.'
            );
        }
        List<XFTY_SharedAncestor> required = new List<XFTY_SharedAncestor>();
        for (String requiredName : REQUIRED_NAMES) {
            required.add(get(requiredName));
        }
        new XFTY_DeclaredAncestorResolver(providerLookup, mode).resolve(required);
        declaredPhaseComplete = true;
    }

    /** Kind + require-state, for the resolver and the "not declared" checks. */
    public Kind getKind() {
        return this.kind;
    }
    public Boolean isRequired() {
        return REQUIRED_NAMES.contains(this.name);
    }
    public Boolean isResolved() {
        return this.resolvedRecord != null;
    }
    public XFTY_LookupKeyIntf getExplicitLookupKey() {
        return this.explicitLookupKey;
    }

    /** Package-internal: the resolver hands back the generated record + its bundle. */
    public void acceptResolved(SObject record, XFTY_DummySObjectBundle bundle, Boolean persisted) {
        this.resolvedRecord = record;
        this.resolvedBundle = bundle;
        this.resolvedRecordIsPersisted = persisted;
    }

    private void assertDeclaredAndRequired() {
        if (this.kind != Kind.DECLARED) {
            return;
        }
        if (!this.isRequired()) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.name + '" is declared but this test did not require it. Add '
                            + 'XFTY_SharedAncestor.require("' + this.name + '") at the top of the test.'
            );
        }
    }

    /**
     * Register a record the test built itself as this shared ancestor - from here
     * `get(name)` resolves to it and no record is generated. Logs a WARN if it
     * replaces a different, already-resolved record.
     */
    public static void put(String name, SObject record) {
        XFTY_SharedAncestor ancestor = get(name);
        if (ancestor.resolvedRecord != null && ancestor.resolvedRecord != record) {
            System.debug(LoggingLevel.WARN,
                    'XFTY_SharedAncestor.put("' + name + '"): replacing an already-resolved record.');
        }
        ancestor.resolvedRecord = record;
        ancestor.resolvedBundle = null;
        // A record handed in with an Id is treated as already inserted.
        ancestor.resolvedRecordIsPersisted = (record != null && record.Id != null);
    }

    /** The resolved record's Id. Throws if it has not been resolved yet this test method. */
    public static Id getId(String name) {
        XFTY_SharedAncestor ancestor = get(name);
        ancestor.assertDeclaredAndRequired();
        if (ancestor.resolvedRecord == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + name + '" is not resolved yet. '
                            + (ancestor.kind == Kind.DECLARED
                                    ? 'Call XFTY_SharedAncestor.resolveDeclared(lookup) (or make any supply*() call) '
                                            + 'after require("' + name + '").'
                                    : 'Reference it from a relationship in a supply*() call first, or register a record '
                                            + 'with XFTY_SharedAncestor.put("' + name + '", record).')
            );
        }
        return ancestor.resolvedRecord.Id;
    }

    // Configuration ----------------------------------------------------------

    /** The override template for the shared record; also identifies its SObject type. */
    public XFTY_SharedAncestor of(SObject overrideTemplate) {
        this.assertUnresolved('of(...)');
        this.overrideTemplate = overrideTemplate;
        return this;
    }

    /** Pin the Provider variant that generates the shared record. */
    public XFTY_SharedAncestor withKey(XFTY_LookupKeyIntf lookupKey) {
        this.assertUnresolved('withKey(...)');
        this.explicitLookupKey = lookupKey;
        return this;
    }

    /** Copy this field from the shared record into the child's lookup, instead of its Id. */
    public XFTY_SharedAncestor copyingRelatedField(SObjectField relatedField) {
        this.assertUnresolved('copyingRelatedField(...)');
        this.relatedField = relatedField;
        return this;
    }

    private void assertUnresolved(String call) {
        if (this.resolvedRecord != null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.name + '" is already resolved; ' + call + ' would have no effect.'
            );
        }
    }

    // XFTY_DummyDefaultRelationshipIntf ------------------------------------

    public SObject getOverrideTemplate() {
        return this.overrideTemplate;
    }

    public SObjectField getRelatedField() {
        return this.relatedField;
    }

    public XFTY_LookupKeyIntf resolveLookupKey(XFTY_DummySObjectProviderLookupIntf providerLookup) {
        if (this.resolvedLookupKey == null) {
            this.resolvedLookupKey = (this.explicitLookupKey != null)
                    ? this.explicitLookupKey
                    : XFTY_ProviderLookups.resolve(providerLookup, this.requireTemplate());
        }
        return this.resolvedLookupKey;
    }

    // XFTY_SharedRelationshipIntf ----------------------------------------

    public String getSharedName() {
        return this.name;
    }

    public SObject resolveSharedRecord(XFTY_GenerationContext context) {
        if (this.resolvedRecord != null) {
            return this.resolvedRecord;
        }
        this.assertDeclaredAndRequired();
        if (this.kind == Kind.DECLARED) {
            // A required declared ancestor should already be resolved by the S0-S2
            // pre-phase; reaching an unresolved one means the pre-phase never ran.
            XFTY_SharedAncestor.ensureDeclaredResolved(context.providerLookup, context.insertMode);
            if (this.resolvedRecord != null) {
                return this.resolvedRecord;
            }
        }
        this.assertNotAlreadyResolving();
        this.resolutionInProgress = true;
        try {
            this.generateSharedRecord(context);
        } finally {
            this.resolutionInProgress = false;
        }
        return this.resolvedRecord;
    }

    private void assertNotAlreadyResolving() {
        if (!this.resolutionInProgress) {
            return;
        }
        throw new XFTY_DummySObjectFtyProviderException(
                'Shared ancestor "' + this.name + '" references itself while resolving - directly, through a '
                        + 'relationship on its own Provider, or round a chain of other shared ancestors - a cycle. '
                        + 'An on-demand shared ancestor must be lightweight with no ancestors of its own; break the '
                        + 'cycle by registering one side with XFTY_SharedAncestor.put("' + this.name + '", record).'
        );
    }

    private void generateSharedRecord(XFTY_GenerationContext context) {
        XFTY_GenerationContext ancestorContext = context.forRelated();
        XFTY_DummySobjectProviderIntf provider =
                context.providerLookup.get(this.resolveLookupKey(context.providerLookup));
        this.resolvedBundle = provider.createBundle(
                ancestorContext,
                new List<SObject>{ this.requireTemplate().clone(true, true, true, true) }
        );
        this.resolvedRecord = this.resolvedBundle.getList(provider.getPrimaryTargetField())[0];
        this.resolvedRecordIsPersisted = XFTY_InsertModeEnum.NOW == ancestorContext.insertMode;
    }

    /**
     * A bundle exposing the shared record as a single-record sub-graph. It is the
     * bundle produced when the record was generated; for a record supplied with
     * `put(name, record)` there is no such bundle, so one wrapping just that
     * record is built on first request, keyed by its `Id` field. Never null once
     * the shared ancestor is resolved - `bundle.getBundle(field)` and
     * `bundle.getList(field)` stay consistent.
     */
    public XFTY_DummySObjectBundle getResolvedBundle() {
        if (this.resolvedBundle == null && this.resolvedRecord != null) {
            this.resolvedBundle = wrap(this.resolvedRecord);
        }
        return this.resolvedBundle;
    }

    private static XFTY_DummySObjectBundle wrap(SObject record) {
        SObjectField idField = record.getSObjectType()
                .getDescribe()
                .fields
                .getMap()
                .get('Id');
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(idField, new List<SObject>{ record });
        return bundle;
    }

    /**
     * Whether the shared record has been inserted (has a real Id). A child being
     * generated with `NOW` needs this to be true, or its lookup would carry a
     * mock / null Id into a real `insert`.
     */
    public Boolean isResolvedRecordPersisted() {
        return this.resolvedRecordIsPersisted;
    }

    private SObject requireTemplate() {
        if (this.overrideTemplate == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + this.name + '" was never configured. Call '
                            + 'XFTY_SharedAncestor.get("' + this.name + '").of(new SomeSObject()) before generating.'
            );
        }
        return this.overrideTemplate;
    }
}
