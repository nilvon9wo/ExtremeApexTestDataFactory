/**
 * Turns one master template plus the test's own partial templates into a wired
 * `XFTY_DummySObjectBundle`. `build` names the phases; each phase is its own class.
 */
@IsTest
public class XFTY_DummySObjectFactory {

    public static XFTY_DummySObjectBundle createBundle(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate masterTemplate,
            List<SObject> testTemplates
    ) {
        XFTY_DummySObjectFactory generation = new XFTY_DummySObjectFactory(context, masterTemplate);
        return generation.build(testTemplates);
    }

    /** Clone `testTemplate` and fill every field whose master-template value is a plain default. */
    public static SObject cloneAndCompletePlainValues(
            XFTY_DummySObjectMasterTemplate template,
            SObject testTemplate
    ) {
        return XFTY_PlainValues.completedClone(template, testTemplate);
    }

    private final XFTY_GenerationContext context;
    private final XFTY_DummySObjectMasterTemplate template;

    private XFTY_DummySObjectFactory(XFTY_GenerationContext context, XFTY_DummySObjectMasterTemplate masterTemplate) {
        this.context = context;
        this.template = XFTY_ForcedRelationships.appliedTo(context.forcedRelationshipPaths, masterTemplate);
    }

    private XFTY_DummySObjectBundle build(List<SObject> testTemplates) {
        Integer quantity = testTemplates.size();
        XFTY_DummySObjectBundle bundle = XFTY_AncestorRecords.forGeneration(this.context, this.template, quantity);
        List<SObject> records = XFTY_PlainValues.completedClones(this.template, testTemplates);
        bundle.putPrimaries(this.template.primaryTargetField, records);
        XFTY_LookupWiring.wire(this.context, this.template, bundle, records);
        XFTY_ContextAwareValuePass.complete(this.context, this.template, bundle, records);
        XFTY_RecordPersistence.apply(this.context.insertMode, records);
        return bundle;
    }
}
