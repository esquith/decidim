# frozen_string_literal: true

require "spec_helper"

describe "Admin manages projects" do
  let(:manifest_name) { "budgets" }
  let(:budget) { create(:budget, component: current_component) }
  let!(:project) { create(:project, budget:) }
  let!(:destination_budget) { create(:budget, component: current_component) }

  include_context "when managing a component as an admin"

  before do
    budget
    switch_to_host(organization.host)
    login_as user, scope: :user
    visit_component_admin

    within "tr", text: translated(budget.title) do
      page.find(".action-icon--edit-projects").click
    end
  end

  it_behaves_like "manage projects"
  it_behaves_like "import proposals to projects"
  it_behaves_like "export projects"

  describe "bulk actions" do
    let!(:project2) { create(:project, budget:) }
    let!(:category) { create(:category, participatory_space: current_component.participatory_space) }
    let!(:scope) { create(:scope, organization: current_component.organization) }

    before do
      visit current_path
    end

    it "changes projects category" do
      find(".js-resource-id-#{project.id}").set(true)
      find_by_id("js-bulk-actions-button").click
      click_on "Change category"
      select translated(category.name), from: "category_id"
      click_on "Update"

      expect(page).to have_admin_callout "Projects successfully updated to the category"
      within "tr[data-id='#{project.id}']" do
        expect(page).to have_content(translated(category.name))
      end
      expect(Decidim::Budgets::Project.find(project.id).category).to eq(category)
      expect(Decidim::Budgets::Project.find(project2.id).category).to be_nil
    end

    it "changes projects scope" do
      find(".js-resource-id-#{project.id}").set(true)
      find_by_id("js-bulk-actions-button").click
      click_on "Change scope"
      select translated(scope.name), from: :scope_id
      click_on "Update"

      expect(page).to have_admin_callout "Projects successfully updated to the scope"
      within "tr[data-id='#{project.id}']" do
        expect(page).to have_content(translated(scope.name))
      end
      expect(Decidim::Budgets::Project.find(project.id).scope).to eq(scope)
      expect(Decidim::Budgets::Project.find(project2.id).scope).to be_nil
    end

    it "selects projects to implementation" do
      within "tr[data-id='#{project.id}']" do
        expect(page).to have_content("No")
      end
      within "tr[data-id='#{project2.id}']" do
        expect(page).to have_content("No")
      end

      find_by_id("projects_bulk").set(true)
      find_by_id("js-bulk-actions-button").click
      click_on "Change selected"
      select "Select", from: "selected_value"
      click_on "Update"

      expect(page).to have_admin_callout "These projects were successfully selected for implementation"
      within "tr[data-id='#{project.id}']" do
        expect(page).to have_content("Yes")
      end
      within "tr[data-id='#{project2.id}']" do
        expect(page).to have_content("Yes")
      end
      expect(Decidim::Budgets::Project.find(project.id).selected_at).to eq(Time.zone.today)
      expect(Decidim::Budgets::Project.find(project2.id).selected_at).to eq(Time.zone.today)
    end

    describe "when managing a project with scopes" do
      let!(:project) { create(:project, component: current_component) }
      let!(:scope) { create(:scope, organization: current_component.organization) }

      it "does not display subscopes" do
        expect(page).to have_no_content(scope.name)
      end
    end

    describe "update projects budget" do
      let!(:another_component) { create(:budgets_component, organization:, participatory_space: current_component.participatory_space) }
      let!(:another_budget) { create(:budget, component: another_component) }

      it "shows all of the budgets within the participatory_space" do
        visit current_path
        find_by_id("projects_bulk").set(true)
        find_by_id("js-bulk-actions-button").click
        click_on "Change budget"
        options = ["Select budget", format_title(destination_budget), format_title(budget), format_title(another_budget)]
        expect(page).to have_select("reference_id", options:)
      end

      it "changes project budget" do
        find_by_id("projects_bulk").set(true)
        find_by_id("js-bulk-actions-button").click
        click_on "Change budget"
        select translated(destination_budget.title), from: "reference_id"
        click_on "Update project's budget"
        within_flash_messages do
          expect(page).to have_content("Projects successfully updated to the budget: #{translated(project.title)} and #{translated(project2.title)}")
        end
        expect(page).to have_no_css("tr[data-id='#{project.id}']")
        expect(page).to have_no_css("tr[data-id='#{project2.id}']")

        expect(project.reload.budget).to eq(destination_budget)
        expect(project2.reload.budget).to eq(destination_budget)
      end
    end
  end

  private

  def format_title(budget)
    "     #{translated(budget.title)}"
  end
end
