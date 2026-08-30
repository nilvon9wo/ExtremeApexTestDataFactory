/**
 * Coverage for `XFTY_GenerationContext` - the constructor guards, the null
 * defaults, and the `forRelated()` recursion transforms.
 */
@IsTest
private class XFTY_GenerationContextTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    @IsTest
    static void constructorKeepsWhatItIsGiven() {
        XFTY_GenerationContext context = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.NOW, XFTY_InsertInclusivityEnum.ALL
        );

        Assert.areEqual(LOOKUP, context.providerLookup);
        Assert.areEqual(XFTY_InsertModeEnum.NOW, context.insertMode);
        Assert.areEqual(XFTY_InsertInclusivityEnum.ALL, context.inclusivity);
    }

    @IsTest
    static void constructorRejectsANullProviderLookup() {
        try {
            new XFTY_GenerationContext(null, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('Provider Lookup'), ex.getMessage());
        }
    }

    @IsTest
    static void constructorDefaultsANullModeAndInclusivityToTheSafeValues() {
        XFTY_GenerationContext context = new XFTY_GenerationContext(LOOKUP, null, null);

        Assert.areEqual(XFTY_InsertModeEnum.NEVER, context.insertMode, 'null mode defaults to NEVER');
        Assert.areEqual(XFTY_InsertInclusivityEnum.NONE, context.inclusivity, 'null inclusivity defaults to NONE');
    }

    @IsTest
    static void forRelatedTurnsRelatedOnlyIntoNow() {
        XFTY_GenerationContext related = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.RELATED_ONLY, XFTY_InsertInclusivityEnum.REQUIRED
        ).forRelated();

        Assert.areEqual(XFTY_InsertModeEnum.NOW, related.insertMode, 'ancestors of a RELATED_ONLY run are inserted');
        Assert.areEqual(XFTY_InsertInclusivityEnum.REQUIRED, related.inclusivity, 'inclusivity is unchanged');
    }

    @IsTest
    static void forRelatedTurnsPreventCascadeIntoNone() {
        XFTY_GenerationContext related = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.PREVENT_CASCADE
        ).forRelated();

        Assert.areEqual(XFTY_InsertInclusivityEnum.NONE, related.inclusivity, 'the cascade stops one level down');
        Assert.areEqual(XFTY_InsertModeEnum.MOCK, related.insertMode, 'insert mode is unchanged');
    }

    @IsTest
    static void forRelatedCarriesEveryOtherModeAndInclusivityThrough() {
        XFTY_GenerationContext related = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.NOW, XFTY_InsertInclusivityEnum.ALL
        ).forRelated();

        Assert.areEqual(XFTY_InsertModeEnum.NOW, related.insertMode);
        Assert.areEqual(XFTY_InsertInclusivityEnum.ALL, related.inclusivity);
        Assert.areEqual(LOOKUP, related.providerLookup, 'the Provider Lookup is always carried through');
    }
}
