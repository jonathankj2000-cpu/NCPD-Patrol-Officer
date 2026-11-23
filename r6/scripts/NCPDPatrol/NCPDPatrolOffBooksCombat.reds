// Native PSM decisions own all resets and blackboard changes. The untouched
// native Tier2 request resumes as soon as the encounter exception is false.
@wrapMethod(SceneTierInitialDecisions)
protected final const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    if NCPDPatrolOffBooksSystem.RestaurantExploration(stateContext, scriptInterface) { return false; };
    return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(SceneTierIIDecisions)
protected final const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    if NCPDPatrolOffBooksSystem.RestaurantExploration(stateContext, scriptInterface) { return false; };
    return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(SceneTierAbstractDecisions)
protected final const func ToExploration(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    if NCPDPatrolOffBooksSystem.RestaurantExploration(stateContext, scriptInterface) { return true; };
    return wrappedMethod(stateContext, scriptInterface);
}
