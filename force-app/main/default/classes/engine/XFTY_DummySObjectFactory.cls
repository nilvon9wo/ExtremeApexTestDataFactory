/**
 * Turns one master template plus the test's own partial templates into a wired
 * `XFTY_DummySObjectBundle`. `build` names the phases; each phase is its own class.
 */
@IsTest
public class XFTY_DummySObjectFactory {

    private final XFTY_GenerationContext context;
    private final XFTY_DummySObjectMasterTemplate template;

    private XFTY_DummySObjectFactory(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate masterTemplate
    ) {
        this.context = context;
        XFTY_DummySObjectMasterTemplate forced =
                XFTY_RelationshipForcer.apply(context.forcedRelationshipPaths, masterTemplate);
        this.template = XFTY_PathValueApplier.apply(context.pathValues, forced);
    }

    public static XFTY_DummySObjectBundle createBundle(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate masterTemplate,
            List<SObject> testTemplates
    ) {
        return new XFTY_DummySObjectFactory(context, masterTemplate)
                .build(testTemplates);
    }

    private XFTY_DummySObjectBundle build(List<SObject> testTemplates) {
        Integer quantity = testTemplates.size();
        XFTY_DummySObjectBundle bundle = new XFTY_AncestorGenerator(this.context, quantity, this.template)
                .generate();
        List<SObject> records = XFTY_PlainValueFiller.cloneAndCompletePlainValues(this.template, testTemplates);
        bundle.putPrimaries(this.template.primaryTargetField, records);
        new XFTY_LookupWiring(bundle, this.context, this.template)
                .wire();
        new XFTY_ContextAwareValuePass(bundle, this.context, this.template)
                .complete();
        this.registerDeferredValues(bundle);
        this.persist(records);
        return bundle;
    }

    /**
     * Up-flowing values ({@link XFTY_CopyFromDescendantExpression}) are left unresolved and
     * handed to the bundle for the `DEFERRED` flush to fill. In any other mode the
     * whole forest never exists, so it is a loud error, not a silent `null`.
     */
    private void registerDeferredValues(XFTY_DummySObjectBundle bundle) {
        if (this.template.deferredExpressionBySObjectFieldMap.isEmpty()) {
            return;
        }
        if (!this.context.batchedInsertPending) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'A value that reads up from a generated child (XFTY_CopyFromDescendantExpression) needs the DEFERRED '
                            + 'insert mode - the child must exist before it can be read. Use '
                            + 'setInsertMode(XFTY_InsertModeEnum.DEFERRED) and call XFTY_DeferredInserter.flush().'
            );
        }
        bundle.deferValues(this.template.deferredExpressionBySObjectFieldMap);
    }

    private void persist(List<SObject> records) {
        switch on this.context.insertMode {
            when NOW {
                insert records;
            }
            when MOCK {
                XFTY_IdMocker.addIds(records);
            }
        }
    }
}
