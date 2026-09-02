/**
 * This class is responsible for providing test data.
 *
 * It provides the primary entry point for the Extreme Apex Test Data Factory,
 * from which this code is adapted.
 * @see <a href="https://github.com/nilvon9wo/ExtremeApexTestDataFactory/">ExtremeApexTestDataFactory GitHub Repo</a>
 *
 * WARNING:
 * Because Salesforce `@TestSetup` is quirky (and arguably not such a great practice as
 * Salesforce would have developers believe), using this framework with `@TestSetup`
 * is not supported.  Specifically, there is a known issue with `@TestSetup` resetting
 * static variables which this framework depends upon.
 * (These variables do NOT allow communication between each test ALWAYS runs in separate context!)
 */
@IsTest
public class XFTY_DummySObjectProvider {
    private SObjectType sObjectType;
    private final XFTY_DummySObjectProviderLookupIntf sObjectProviderLookup;

    public XFTY_DummySObjectProvider(SObjectType sObjectType, XFTY_DummySObjectProviderLookupIntf sObjectProviderLookup) {
        if (sObjectType == null) {
            throw new SanityException('It is required to specify an SObjectType to request data!');
        }
        this.sObjectType = sObjectType;

        if (sObjectProviderLookup == null) {
            throw new SanityException('It is required to specify an Dummy SObject Provider Lookup to request data!');
        }
        this.sObjectProviderLookup = sObjectProviderLookup;
    }

    /**
     * Convenience: start from a lookup key. The `SObjectType` is taken from the
     * key and the key is pinned as the variant (equivalent to
     * `new XFTY_DummySObjectProvider(key.getSObjectType(), lookup).withVariant(key)`).
     */
    public XFTY_DummySObjectProvider(XFTY_LookupKeyIntf variantKey, XFTY_DummySObjectProviderLookupIntf sObjectProviderLookup) {
        this(typeOf(variantKey), sObjectProviderLookup);
        this.explicitVariantKey = variantKey;
    }

    /**
     * Convenience: start from an override template. The `SObjectType` is taken
     * from the template and the template becomes the (single) override template,
     * so the variant is resolved from it too - equivalent to
     * `new XFTY_DummySObjectProvider(template.getSObjectType(), lookup).setOverrideTemplate(template)`.
     */
    public XFTY_DummySObjectProvider(SObject overrideTemplate, XFTY_DummySObjectProviderLookupIntf sObjectProviderLookup) {
        this(new List<SObject>{ overrideTemplate }, sObjectProviderLookup);
    }

    /**
     * Convenience: start from a list of override templates. The `SObjectType` is
     * taken from the first template - equivalent to
     * `new XFTY_DummySObjectProvider(list[0].getSObjectType(), lookup).setOverrideTemplateList(list)`.
     */
    public XFTY_DummySObjectProvider(List<SObject> overrideTemplateList, XFTY_DummySObjectProviderLookupIntf sObjectProviderLookup) {
        this(typeOf(overrideTemplateList), sObjectProviderLookup);
        this.setOverrideTemplateList(overrideTemplateList);
    }

    private static SObjectType typeOf(XFTY_LookupKeyIntf variantKey) {
        if (variantKey == null) {
            throw new SanityException('It is required to specify a lookup key to request data!');
        }
        return variantKey.getSObjectType();
    }

    private static SObjectType typeOf(List<SObject> overrideTemplateList) {
        if (overrideTemplateList == null || overrideTemplateList.isEmpty() || overrideTemplateList[0] == null) {
            throw new SanityException(
                    'Cannot derive an SObjectType from an empty or null template list - '
                            + 'supply at least one concrete template, or use the (SObjectType, lookup) constructor.'
            );
        }
        return overrideTemplateList[0].getSObjectType();
    }

    private List<SObject> overrideTemplateList;
    private XFTY_LookupKeyIntf explicitVariantKey;
    private final List<List<SObjectField>> forcedRelationshipPaths = new List<List<SObjectField>>();
    private Integer quantityPerListedTemplate = 1; // If no templates are supplied, a blank one will be created.
    private XFTY_InsertModeEnum insertMode = XFTY_InsertModeEnum.NEVER;
    private XFTY_InsertInclusivityEnum inclusivity = XFTY_InsertInclusivityEnum.NONE;
    private Boolean hasCustomMasterTemplate = false;
    private Boolean depthBatched = false;
    private Boolean ancestorCyclesAllowed = false;

    // `sObjectType` is set non-null by every constructor and never reassigned; the
    // class is not subclassable. So the code below never sees a null type - no
    // guard is needed. If a "construct now, set the type later" flow is ever
    // added, reinstate a guard + a dedicated exception here.

    private final XFTY_DummySobjectProviderIntf factoryOutlet {
        get {
            if (this.factoryOutlet == null) {
                this.factoryOutlet = this.sObjectProviderLookup.get(this.resolveVariantKey());
            }
            return this.factoryOutlet;
        }
        private set;
    }

    /**
     * Which Provider variant to use: an explicit key from `withVariant(...)`, or
     * the key derived from the first override template (so a template carrying a
     * record type reaches the matching Provider), or the plain SObjectType key.
     *
     * Only consulted the first time the Provider is resolved - if `put(...)` /
     * `removeFromMasterTemplate(...)` has already run, the variant is fixed;
     * `withVariant(...)` therefore rejects a late call.
     */
    private XFTY_LookupKeyIntf resolveVariantKey() {
        SObject firstTemplate = (this.overrideTemplateList != null && !this.overrideTemplateList.isEmpty())
                ? this.overrideTemplateList[0]
                : null;
        XFTY_LookupKeyIntf key = XFTY_ProviderLookups.reconcile(
                this.sObjectProviderLookup, this.explicitVariantKey, firstTemplate);
        return (key != null) ? key : XFTY_LookupKey.get(this.sObjectType);
    }

    private final XFTY_DummySObjectMasterTemplate masterTemplate {
        get {
            if (this.masterTemplate == null) {
                this.masterTemplate = this.factoryOutlet.getMasterTemplate()
                        .copy();
            }
            return this.masterTemplate;
        }
        private set;
    }

    //  Setters -----------------------------------------------------------------------------------------------------------------

    public XFTY_DummySObjectProvider setQuantityPerTemplate(Integer quantityPerListedTemplate) {
        if (quantityPerListedTemplate < 1) {
            throw new SanityException('It makes no sense to supply ' + quantityPerListedTemplate);
        }
        this.quantityPerListedTemplate = quantityPerListedTemplate;
        return this;
    }

    /**
     * The `SObjectType` set by the constructor always wins - a list of a
     * different type throws {@link ConflictException} rather than silently
     * retargeting the Provider. (The `(List<SObject>, lookup)` constructor derives
     * the type from the list first, so a homogeneous list is fine.)
     */
    public XFTY_DummySObjectProvider setOverrideTemplateList(List<SObject> overrideTemplateList) {
        this.overrideTemplateList = overrideTemplateList;
        this.assertNoSObjectTypeConflict(overrideTemplateList);
        return this;
    }

    public XFTY_DummySObjectProvider setOverrideTemplate(SObject overrideTemplate) {
        return this.setOverrideTemplateList(new List<SObject>{
                overrideTemplate
        });
    }

    /**
     * Pin the Provider variant explicitly (e.g.
     * `XFTY_RecordTypeLookupKey.get(Account.SObjectType, 'PersonAccount')`),
     * instead of letting it be derived from the override template. Must be called
     * before any `put(...)` / `removeFromMasterTemplate(...)`, and the key must be
     * for this Provider's `SObjectType`.
     */
    public XFTY_DummySObjectProvider withVariant(XFTY_LookupKeyIntf variantKey) {
        if (this.hasCustomMasterTemplate) {
            // put(...) already resolved the Provider from the default variant.
            throw new SanityException('Call withVariant(...) before customizing the template with put(...).');
        }
        this.assertVariantKeyMatchesType(variantKey);
        this.explicitVariantKey = variantKey;
        return this;
    }

    private void assertVariantKeyMatchesType(XFTY_LookupKeyIntf variantKey) {
        if (variantKey == null) {
            throw new SanityException('A variant key is required.');
        }
        if (variantKey.getSObjectType() != this.sObjectType) {
            throw new ConflictException(
                    'Variant key is for ' + variantKey.getSObjectType()
                            + ' but this Provider requests ' + this.sObjectType + '.'
            );
        }
    }

    public XFTY_DummySObjectProvider setInsertMode(XFTY_InsertModeEnum insertMode) {
        this.insertMode = insertMode;
        return this;
    }

    public XFTY_DummySObjectProvider setInclusivity(XFTY_InsertInclusivityEnum inclusivity) {
        this.inclusivity = inclusivity;
        return this;
    }

    /**
     * Opt in to one `insert` per dependency depth for this `NOW` call, instead of
     * one per Provider: a `Task` with an `Account` and a `Contact` parent costs 2
     * inserts, not 3.
     *
     * Opt-in because it changes `insert` order - and the order triggers fire
     * during generation - which some tests rely on. No effect on the modes that
     * do no DML. Not supported with shared ancestors.
     */
    public XFTY_DummySObjectProvider depthBatched() {
        this.depthBatched = true;
        return this;
    }

    /**
     * Suppress the ancestor-cycle guard for this call. Relationship generation
     * normally throws when it would generate a second record of a type already
     * being generated up the graph (an infinite `A -> A -> A ...`). Use this only
     * when the chain genuinely terminates on its own - or when the guard is a
     * false positive - and you accept responsibility for that.
     */
    public XFTY_DummySObjectProvider allowAncestorCycles() {
        this.ancestorCyclesAllowed = true;
        return this;
    }

    // Include methods ----------------------------------------------------------------------------------------------------------
    // Use these when static templates are insufficient (e.g. because unique values are required).
    // WARNING: You can use both override templates and include methods, but in the event of conflicting values, override values will win!

    public XFTY_DummySObjectProvider put(SObjectField sObjectField, XFTY_ValueExpressionIntf valueTemplate) {
        this.masterTemplate.remove(sObjectField);
        this.masterTemplate.put(sObjectField, valueTemplate);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    public XFTY_DummySObjectProvider put(SObjectField sObjectField, XFTY_ContextAwareExpressionIntf contextAwareExpression) {
        this.masterTemplate.remove(sObjectField);
        this.masterTemplate.put(sObjectField, contextAwareExpression);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    /** An up-flowing value ({@link XFTY_CopyFromDescendantExpression}); needs the DEFERRED insert mode. */
    public XFTY_DummySObjectProvider put(SObjectField sObjectField, XFTY_DeferredExpressionIntf deferredValue) {
        this.masterTemplate.remove(sObjectField);
        this.masterTemplate.put(sObjectField, deferredValue);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    public XFTY_DummySObjectProvider putRequired(SObjectField sObjectField, XFTY_DummyDefaultRelationshipIntf relationshipTemplate) {
        this.masterTemplate.remove(sObjectField);
        this.masterTemplate.putRequired(sObjectField, relationshipTemplate);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    public XFTY_DummySObjectProvider putOptional(SObjectField sObjectField, XFTY_DummyDefaultRelationshipIntf relationshipTemplate) {
        this.masterTemplate.remove(sObjectField);
        this.masterTemplate.putOptional(sObjectField, relationshipTemplate);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    /**
     * Convenience overload mirroring `XFTY_DummySObjectMasterTemplate.put(SObjectField, Object)`:
     * a context-aware expression, a plain value expression, or (anything else) a bare
     * literal wrapped in `XFTY_LiteralExpression`. Relationships are rejected -
     * use `putRequired(...)` / `putOptional(...)`.
     */
    public XFTY_DummySObjectProvider put(SObjectField sObjectField, Object value) {
        if (value instanceof XFTY_DeferredExpressionIntf) {
            return this.put(sObjectField, (XFTY_DeferredExpressionIntf) value);
        }
        if (value instanceof XFTY_ContextAwareExpressionIntf) {
            return this.put(sObjectField, (XFTY_ContextAwareExpressionIntf) value);
        }
        if (value instanceof XFTY_ValueExpressionIntf) {
            return this.put(sObjectField, (XFTY_ValueExpressionIntf) value);
        }
        if (value instanceof XFTY_DummyDefaultRelationshipIntf) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Relationships must be added with putRequired(...) or putOptional(...), not put(...).'
            );
        }
        return this.put(sObjectField, new XFTY_LiteralExpression(value));
    }

    //noinspection ApexUnusedDeclaration
    public XFTY_DummySObjectProvider removeFromMasterTemplate(SObjectField sObjectField){
        this.masterTemplate.remove(sObjectField);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    // Per-call relationship control ------------------------------------------------------------------------------------------
    // Both act only on THIS Provider instance (its own copy of the Master Template) - a
    // different Provider sharing the same static Master Template is unaffected. Call
    // before customizing with put(...) (same rule as withVariant).

    /**
     * Generate one specific relationship on this call, on top of whatever
     * `setInclusivity(...)` covers - promote it to required for this instance.
     * Equivalent to `includeOptional(new List<SObjectField>{ sObjectField })`.
     */
    public XFTY_DummySObjectProvider includeOptional(SObjectField sObjectField) {
        return this.includeOptional(new List<SObjectField>{ sObjectField });
    }

    /**
     * Reach down the graph: force every relationship along the path for this call.
     * `includeOptional(new List<SObjectField>{ Opportunity.Pricebook2Id, Pricebook2.OwnerId })`
     * makes the generated Opportunity's Pricebook, and *its* Owner, both required -
     * for this call only. Each step must be a relationship on the Provider it
     * resolves to (an unknown step throws during generation); whether that
     * relationship is a plain one or a shared ancestor makes no difference.
     */
    public XFTY_DummySObjectProvider includeOptional(List<SObjectField> relationshipPath) {
        if (relationshipPath == null || relationshipPath.isEmpty()) {
            throw new SanityException('includeOptional(...) needs at least one relationship field.');
        }
        for (SObjectField step : relationshipPath) {
            if (step == null) {
                throw new SanityException('includeOptional(...) path steps cannot be null.');
            }
        }
        this.forcedRelationshipPaths.add(relationshipPath);
        return this;
    }

    // Path-scoped value overrides -----------------------------------------------------------------------------------------
    // put(path, value) walks a path of relationship fields into a generated ancestor and sets
    // its target field (the last element), for this call only. Every relationship on the way is
    // forced generated (as includeOptional does). See docs/roadmap/path-scoped-values.md.

    private final List<XFTY_PathValue> pathValues = new List<XFTY_PathValue>();

    /** `put([Opportunity.Pricebook2Id, Pricebook2.Name], strategy)` - set a field on a generated ancestor. */
    public XFTY_DummySObjectProvider put(List<SObjectField> path, XFTY_ValueExpressionIntf valueExpression) {
        this.pathValues.add(XFTY_PathValue.ofExpression(path, valueExpression));
        return this;
    }

    /** `put([...path], contextAwareExpression)` - the ancestor field is evaluated by a context-aware expression. */
    public XFTY_DummySObjectProvider put(List<SObjectField> path, XFTY_ContextAwareExpressionIntf contextAwareExpression) {
        this.pathValues.add(XFTY_PathValue.ofContextAware(path, contextAwareExpression));
        return this;
    }

    /** `put([...path], literal)` - a constant on a generated ancestor's field. */
    public XFTY_DummySObjectProvider put(List<SObjectField> path, Object literal) {
        this.pathValues.add(XFTY_PathValue.ofLiteral(path, literal));
        return this;
    }

    /** `putRequired([...path], relationship)` - a generated ancestor's own lookup gets a generated parent. */
    public XFTY_DummySObjectProvider putRequired(List<SObjectField> path, XFTY_DummyDefaultRelationshipIntf relationship) {
        this.pathValues.add(XFTY_PathValue.ofRequiredRelationship(path, relationship));
        return this;
    }

    /** `putOptional([...path], relationship)` - as `putRequired([...path], ...)` but optional on the ancestor. */
    public XFTY_DummySObjectProvider putOptional(List<SObjectField> path, XFTY_DummyDefaultRelationshipIntf relationship) {
        this.pathValues.add(XFTY_PathValue.ofOptionalRelationship(path, relationship));
        return this;
    }

    /**
     * Do not generate one specific relationship on this call - required or
     * optional. For this instance the relationship becomes non-existent: not
     * generated, not attached, not left as an orphan. Throws if `sObjectField` is
     * not a relationship on this Provider (use `removeFromMasterTemplate(...)` for
     * plain value fields).
     */
    public XFTY_DummySObjectProvider excludeRelationship(SObjectField sObjectField) {
        Boolean isRelationship =
                this.masterTemplate.requiredRelationshipBySObjectFieldMap.containsKey(sObjectField)
                        || this.masterTemplate.optionalRelationshipBySObjectFieldMap.containsKey(sObjectField);
        if (!isRelationship) {
            throw new SanityException(
                    'excludeRelationship(' + sObjectField + '): ' + this.sObjectType
                            + ' has no relationship on that field.'
            );
        }
        this.masterTemplate.remove(sObjectField);
        this.hasCustomMasterTemplate = true;
        return this;
    }

    /** Like `excludeRelationship`, but a no-op when the field is not a relationship on this Provider. */
    public XFTY_DummySObjectProvider excludeRelationshipIfPresent(SObjectField sObjectField) {
        Boolean isRelationship =
                this.masterTemplate.requiredRelationshipBySObjectFieldMap.containsKey(sObjectField)
                        || this.masterTemplate.optionalRelationshipBySObjectFieldMap.containsKey(sObjectField);
        if (isRelationship) {
            this.masterTemplate.remove(sObjectField);
            this.hasCustomMasterTemplate = true;
        }
        return this;
    }

    // Downward generation - child collections --------------------------------------------------------------------------------
    //
    // The framework generates upward by default (a record pulls in the parents it needs).
    // `with(...)` / `withChildren(...)` / `withChild(...)` generate records that hang BELOW
    // this Provider's primaries. See docs/use/child-records.md.

    private final List<XFTY_SObjectChildProvider> childProviders = new List<XFTY_SObjectChildProvider>();
    private Boolean forceStructuralChildGeneration = false;

    /**
     * Add a fully-configured child collection. Repeatable - a `Contact` collection
     * and a `Case` collection on the same Account both apply; two `Contact`
     * collections on `Contact.AccountId` with different templates are additive.
     */
    public XFTY_DummySObjectProvider with(XFTY_SObjectChildProvider childProvider) {
        if (childProvider == null) {
            throw new SanityException('with(...) needs an XFTY_SObjectChildProvider.');
        }
        XFTY_SObjectChildProvider.assertFieldPointsAt(childProvider.relationshipField, this.sObjectType);
        this.childProviders.add(childProvider);
        return this;
    }

    /** Internal: a child of a DEFERRED / depthBatched parent must build its own children structurally too. */
    public XFTY_DummySObjectProvider forceStructuralChildGeneration() {
        this.forceStructuralChildGeneration = true;
        return this;
    }

    /** Shortcut: `countPerParent` children on `childRelationshipField`, everything else defaulted. */
    public XFTY_DummySObjectProvider withChildren(SObjectField childRelationshipField, Integer countPerParent) {
        return this.with(new XFTY_SObjectChildProvider(childRelationshipField).setQuantity(countPerParent));
    }

    /** Shortcut: one child on `childRelationshipField`. */
    public XFTY_DummySObjectProvider withChild(SObjectField childRelationshipField) {
        return this.with(new XFTY_SObjectChildProvider(childRelationshipField));
    }

    private void generateChildren(XFTY_DummySObjectBundle bundle, Boolean structural) {
        if (this.childProviders.isEmpty()) {
            return;
        }
        for (XFTY_SObjectChildProvider childProvider : this.childProviders) {
            this.generateOneChildCollection(bundle, childProvider, structural);
        }
    }

    private void generateOneChildCollection(
            XFTY_DummySObjectBundle bundle,
            XFTY_SObjectChildProvider childProvider,
            Boolean structural
    ) {
        List<SObject> primaries = bundle.getList(this.factoryOutlet.getPrimaryTargetField());
        List<SObject> childTemplates = new List<SObject>();
        List<Integer> parentRowByChildRow = new List<Integer>();
        for (Integer parentRow = 0; parentRow < primaries.size(); parentRow++) {
            Id parentId = structural ? null : primaries[parentRow].Id;
            for (SObject childTemplate : childProvider.templatesForParent(parentId)) {
                childTemplates.add(childTemplate);
                parentRowByChildRow.add(parentRow);
            }
        }

        XFTY_InsertModeEnum childMode = structural
                ? XFTY_InsertModeEnum.NEVER
                : childProvider.effectiveInsertMode(this.insertMode);

        XFTY_DummySObjectProvider childInstance = childProvider.newProvider(this.sObjectProviderLookup)
                .setOverrideTemplateList(childTemplates)
                .setInsertMode(childMode)
                .setInclusivity(childProvider.effectiveInclusivity(this.inclusivity));
        if (structural) {
            // The back-reference is wired by the deferred buffer at flush, so the
            // child must not also generate its own parent on that field, and its
            // own children stay structural for the same flush.
            childInstance
                    .excludeRelationshipIfPresent(childProvider.relationshipField)
                    .forceStructuralChildGeneration();
        }

        XFTY_DummySObjectBundle childBundle = childInstance.supplyBundle();

        bundle.putChild(childProvider.relationshipField, childBundle, parentRowByChildRow);
    }

    // Supply methods ----------------------------------------------------------------------------------------------------------

    public XFTY_DummySObjectBundle supplyBundle() {
        this.warnIfMixingCustomTemplateWithOverrides();
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        // Every configured shared ancestor resolves up front, honouring this call's mode.
        XFTY_SharedAncestorResolver.resolveAllConfigured(this.sObjectProviderLookup, this.insertMode);
        XFTY_GenerationContext context = this.buildContext();
        List<SObject> templates = this.templatesToFill();
        XFTY_DummySObjectBundle bundle = this.generate(context, templates);
        if (this.buildsStructurallyForBatchedInsert()) {
            // Children join the same deferred graph - generated structurally now,
            // FK wired when the buffer flushes (parents first).
            this.generateChildren(bundle, true);
            this.persist(bundle);
        } else if (this.forceStructuralChildGeneration) {
            // A structural child of a deferred parent: nothing to persist here, but
            // its own children stay structural so the flush wires the whole subtree.
            this.generateChildren(bundle, true);
        } else {
            // NOW / MOCK: primaries already have Ids after generate(); wire the
            // children's back-reference concretely. NEVER: no Ids, FK left null.
            this.persist(bundle);
            this.generateChildren(bundle, false);
        }
        budget.warnIfExpensive();
        return bundle;
    }

    private XFTY_DummySObjectBundle generate(XFTY_GenerationContext context, List<SObject> templates) {
        return this.hasCustomMasterTemplate
                ? XFTY_DummySObjectFactory.createBundle(context, this.masterTemplate, templates)
                : this.factoryOutlet.createBundle(context, templates);
    }

    private void persist(XFTY_DummySObjectBundle bundle) {
        if (this.flushesGraphWhenThisCallEnds()) {
            XFTY_DeferredInsertBuffer.insertGraph(bundle);
        } else if (this.deferredToRegistry()) {
            XFTY_DeferredInserter.register(bundle);
        }
    }

    private XFTY_GenerationContext buildContext() {
        XFTY_InsertModeEnum mode = this.contextInsertMode();
        XFTY_GenerationContext context = new XFTY_GenerationContext(this.sObjectProviderLookup, mode, this.inclusivity)
                .withForcedRelationshipPaths(this.forcedRelationshipPaths)
                .withPathValues(this.pathValues)
                .withAncestorCycleGuard(this.ancestorCyclesAllowed);
        return this.buildsStructurallyForBatchedInsert()
                ? context.forBatchedInsert()
                : context;
    }

    private XFTY_InsertModeEnum contextInsertMode() {
        return this.buildsStructurallyForBatchedInsert()
                ? XFTY_InsertModeEnum.NEVER
                : this.insertMode;
    }

    private Boolean buildsStructurallyForBatchedInsert() {
        return this.flushesGraphWhenThisCallEnds()
                || this.deferredToRegistry();
    }

    private Boolean flushesGraphWhenThisCallEnds() {
        return this.depthBatched
                && XFTY_InsertModeEnum.NOW == this.insertMode;
    }

    private Boolean deferredToRegistry() {
        return XFTY_InsertModeEnum.DEFERRED == this.insertMode;
    }

    private List<SObject> templatesToFill() {
        List<SObject> templates = this.suppliedOrBlankTemplates();
        return (this.quantityPerListedTemplate > 1)
                ? this.multiplyByQuantity(templates)
                : templates;
    }

    private List<SObject> suppliedOrBlankTemplates() {
        if (this.hasOverrideTemplates()) {
            return this.overrideTemplateList;
        }
        SObject blank = this.sObjectType.newSObject();
        return new List<SObject>{ blank };
    }

    private Boolean hasOverrideTemplates() {
        if (this.overrideTemplateList == null) {
            return false;
        }
        return !this.overrideTemplateList.isEmpty();
    }

    private void warnIfMixingCustomTemplateWithOverrides() {
        if (this.hasCustomMasterTemplate && this.hasOverrideTemplates()) {
            System.debug(LoggingLevel.WARN, '!!!  Custom master template + overrides: overrides win all conflicts!  !!!');
        }
    }

    private List<SObject> multiplyByQuantity(List<SObject> templateList) {
        List<SObject> multipliedTemplateList = new List<SObject>();
        for (Integer i = 1; i <= this.quantityPerListedTemplate; i++) {
            multipliedTemplateList.addAll(templateList.clone());
        }
        return multipliedTemplateList;
    }

    public List<SObject> supplyList() {
        return this.supplyBundle()
                .getList(this.factoryOutlet.getPrimaryTargetField());
    }

    public SObject supply() {
        return this.supplyList()[0];
    }

    // Consistency checks ----------------------------------------------------------------

    private void assertNoSObjectTypeConflict(List<SObject> overrideTemplateList) {
        if (overrideTemplateList == null || overrideTemplateList.isEmpty()) {
            return;
        }
        for (SObject overrideTemplate : overrideTemplateList) {
            if (overrideTemplate.getSObjectType() != this.sObjectType) {
                throw new ConflictException(
                        'This Provider requests ' + this.sObjectType + ' but was given a '
                                + overrideTemplate.getSObjectType() + ' override template.'
                );
            }
        }
    }

    // Exceptions checks ----------------------------------------------------------------

    public class SanityException extends Exception {
    }
    public class ConflictException extends Exception {
    }
}